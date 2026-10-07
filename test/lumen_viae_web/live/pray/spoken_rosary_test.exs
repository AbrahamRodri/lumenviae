defmodule LumenViaeWeb.Live.Pray.SpokenRosaryTest do
  @moduledoc """
  Praying aloud on the website: the switch, the voice, the script handed
  to the SpokenRosary hook, the page and the bead following the voice, and
  the completion it records.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Ecto.Query
  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import Phoenix.LiveViewTest

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion

  @browser "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.2 Safari/605.1.15"

  # Presigning is local arithmetic over the credentials, so stub ones are
  # enough to build a whole script without reaching AWS.
  setup %{conn: conn} do
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    %{conn: Plug.Conn.put_req_header(conn, "user-agent", @browser)}
  end

  defp create_set(category, count) do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{
          name: "Aloud #{System.unique_integer([:positive])}",
          category: category
        },
        actor: admin()
      )

    for order <- 1..count do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "M #{System.unique_integer([:positive])}",
            category: category,
            order: System.unique_integer([:positive]),
            description: "d"
          },
          actor: admin()
        )

      {:ok, meditation} =
        Rosary.create_meditation(%{content: "c", title: "t", mystery_id: mystery.id},
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    set
  end

  defp script(view) do
    view
    |> element("[phx-hook=SpokenRosary]")
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.attribute("data-script")
    |> hd()
    |> Jason.decode!()
  end

  defp voice_reaches(view, step) do
    view
    |> element("[phx-hook=SpokenRosary]")
    |> render_hook("spoken_at", %{page: step["page"], screen: step["screen"]})
  end

  test "the switch turns the spoken Rosary on and keeps it in the URL", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    refute has_element?(view, "[phx-hook=SpokenRosary]")

    view |> element("button[phx-click=toggle_pray_aloud]") |> render_click()

    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=opening&aloud=true")
    assert has_element?(view, "[id^=spoken-rosary-female][phx-hook=SpokenRosary]")

    # The set's own narration player would talk over it.
    view |> element("button[phx-click=next]") |> render_click()
    refute has_element?(view, "#audio-player")
  end

  test "the hook is handed the whole Rosary in order, with a URL for every prayer",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    steps = script(view)
    captions = Enum.map(steps, & &1["caption"])

    assert hd(captions) == "The Sign of the Cross"
    assert "The Fatima Prayer" in captions
    assert "Hail Mary · 10 of 10" in captions
    assert List.last(captions) == "The Sign of the Cross"
    assert Enum.all?(steps, &String.contains?(&1["url"], "/voices/female/rosary/"))
    # The meditations have no narration here, so they are left out rather
    # than handed to the player as nothing to play.
    refute "The meditation" in captions

    # What the hook reads of a step (assets/js/hooks/spoken_rosary.js), and
    # nothing it does not.
    assert Enum.all?(
             steps,
             &(Map.keys(&1) |> Enum.sort() == ~w(caption page pause_ms screen url))
           )

    # The app's breath after each prayer. (These mysteries' orders have no
    # recorded announcement, so only the prayers are left to play.)
    assert Enum.all?(steps, &(&1["pause_ms"] == 900))

    # Every step names the page it is shown on - the opening, the five
    # decades, the closing - and the screens run in order.
    assert steps |> Enum.map(& &1["page"]) |> Enum.dedup() == [0, 1, 2, 3, 4, 5, 6]
    screens = Enum.map(steps, & &1["screen"])
    assert screens == Enum.sort(screens)
  end

  test "a Seven Sorrows set is prayed as the chaplet", %{conn: conn} do
    set = create_set("seven_sorrows", 7)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    captions = view |> script() |> Enum.map(& &1["caption"])

    assert Enum.take(captions, 2) == ["The Sign of the Cross", "The Act of Contrition"]
    refute "The Fatima Prayer" in captions
    assert "Hail Mary · 7 of 7" in captions
    assert "In honor of her tears · 3 of 3" in captions
  end

  test "choosing a voice re-signs the script in that voice", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    view |> form("form[phx-change=set_voice]", %{voice: "male"}) |> render_change()

    assert has_element?(view, "[id^=spoken-rosary-male]")
    assert view |> script() |> Enum.all?(&String.contains?(&1["url"], "/voices/male/rosary/"))
  end

  test "the Scriptural Rosary is said with its verses", %{conn: conn} do
    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?aloud=true&form=scriptural")

    # These test mysteries have no verses recorded, so none are played;
    # the form is still the Scriptural Rosary's, with no meditation step.
    assert has_element?(view, "[id^=spoken-rosary-female-scriptural]")
  end

  test "the voice reaching a decade turns the page, and turning the page moves the voice",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")
    steps = script(view)

    at = Enum.find(steps, &(&1["page"] == 3))
    voice_reaches(view, at)

    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=2&aloud=true")
    refute_push_event(view, "spoken_seek", %{})

    # Further into the same decade the page stays where it is.
    voice_reaches(view, Enum.find(steps, &(&1["page"] == 3 and &1["screen"] > at["screen"])))
    refute_patched(view)

    view |> element("button[phx-click=next]") |> render_click()
    first_of_next = Enum.find(steps, &(&1["page"] == 4))
    assert_push_event(view, "spoken_seek", %{screen: screen})
    assert screen <= first_of_next["screen"]
  end

  test "counting on the screen, the bead follows the voice and the voice the bead",
       %{conn: conn} do
    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?aloud=true&count=screen")

    hail_mary =
      view
      |> script()
      |> Enum.find(&(&1["caption"] == "Hail Mary · 4 of 10" and &1["page"] == 1))

    voice_reaches(view, hail_mary)

    # The announcement, the meditation, the Our Father, then Hail Marys.
    assert_patch(
      view,
      "/meditation-sets/#{set.id}/pray?mystery=0&step=6&count=screen&aloud=true"
    )

    assert view |> element("#bead-status") |> render() =~ "Hail Mary · 4 of 10"

    render_keydown(view, "key_nav", %{"key" => " "})
    assert_push_event(view, "spoken_seek", %{screen: screen})
    assert screen == hail_mary["screen"] + 1
  end

  test "a place the voice reports from before the reader's last move is not followed",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")
    steps = script(view)

    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=0&aloud=true")
    assert_push_event(view, "spoken_seek", %{seek: seek})

    # Sent before the voice heard the seek: still on the opening prayers.
    opening = Enum.find(steps, &(&1["page"] == 0))

    view
    |> element("[phx-hook=SpokenRosary]")
    |> render_hook("spoken_at", %{page: 0, screen: opening["screen"], seek: seek - 1})

    refute_patched(view)

    # Once it has caught up, it is followed again.
    later = Enum.find(steps, &(&1["page"] == 3))

    view
    |> element("[phx-hook=SpokenRosary]")
    |> render_hook("spoken_at", %{page: 3, screen: later["screen"], seek: seek})

    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=2&aloud=true")
  end

  test "the voice moves nothing once the Rosary is no longer said aloud", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")
    later = view |> script() |> Enum.find(&(&1["page"] == 3))

    view |> element("button[phx-click=toggle_pray_aloud]") |> render_click()
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=opening")

    render_hook(view, "spoken_at", %{page: 3, screen: later["screen"]})
    refute_patched(view)
  end

  test "a Rosary prayed aloud is recorded as prayed aloud", %{conn: conn} do
    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing&aloud=true")

    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == true
  end

  test "a Rosary read silently is recorded as silent", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")

    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == false
  end
end
