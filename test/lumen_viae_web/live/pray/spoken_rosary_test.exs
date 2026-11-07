defmodule LumenViaeWeb.Live.Pray.SpokenRosaryTest do
  @moduledoc """
  Praying aloud on the website, which is the only way to pray there: the
  player, the voice, the script handed to the SpokenRosary hook, the bead
  following the voice, and the completion it records.
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

  test "the player is there on arrival, and old links that said otherwise still get it",
       %{conn: conn} do
    set = create_set("joyful", 5)

    for query <- ["", "?aloud=false", "?aloud=true&count=beads"] do
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray#{query}")

      assert has_element?(view, "[id^=spoken-rosary-female][phx-hook=SpokenRosary]")
      refute has_element?(view, "button[phx-click=toggle_pray_aloud]")
    end

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=false&count=beads")

    # The next URL carries neither choice.
    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=opening&step=1")

    # The set's own narration player would talk over it.
    refute has_element?(view, "#audio-player")
  end

  test "the hook is handed the whole Rosary in order, with a URL for every prayer",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

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
    # nothing it does not. Where a recording has no timed lines they are nil.
    assert Enum.all?(
             steps,
             &(Map.keys(&1) |> Enum.sort() == ~w(caption kind lines page pause_ms screen url))
           )

    assert Enum.all?(steps, &(&1["kind"] in ~w(prayer verse announcement meditation)))
    assert Enum.all?(steps, &(is_nil(&1["lines"]) or is_list(&1["lines"])))

    hail_mary = Enum.find(steps, &(&1["caption"] == "Hail Mary · 10 of 10"))
    assert hail_mary["kind"] == "prayer"

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
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    captions = view |> script() |> Enum.map(& &1["caption"])

    assert Enum.take(captions, 2) == ["The Sign of the Cross", "The Act of Contrition"]
    refute "The Fatima Prayer" in captions
    assert "Hail Mary · 7 of 7" in captions
    assert "In honor of her tears · 3 of 3" in captions
  end

  test "the static render shows the player but signs and sends no script", %{conn: conn} do
    set = create_set("joyful", 5)
    html = conn |> get("/meditation-sets/#{set.id}/pray") |> html_response(200)

    assert [player] = html |> Floki.parse_document!() |> Floki.find("[phx-hook=SpokenRosary]")
    assert Floki.attribute(player, "data-script") == ["[]"]
    refute html =~ "X-Amz-Signature"

    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
    assert script(view) != []
  end

  test "the player can be muted, and the settings offer the prayers' speed", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    assert has_element?(view, "[phx-hook=SpokenRosary] button[data-mute]")

    view |> element("button[aria-controls=prayer-settings]") |> render_click()

    rates =
      view
      |> element("#prayer-speed")
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.attribute("[data-prayer-rate]", "data-prayer-rate")

    assert rates == ~w(0.8 0.9 1 1.1 1.2 1.3)
  end

  test "choosing a voice re-signs the script in that voice", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    view |> element("button[aria-controls=prayer-settings]") |> render_click()
    view |> element("#prayer-settings button[phx-value-voice=male]") |> render_click()

    assert has_element?(view, "[id^=spoken-rosary-male]")
    assert view |> script() |> Enum.all?(&String.contains?(&1["url"], "/voices/male/rosary/"))
  end

  test "the Scriptural Rosary is said with its verses", %{conn: conn} do
    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?form=scriptural")

    # These test mysteries have no verses recorded, so none are played;
    # the form is still the Scriptural Rosary's, with no meditation step.
    assert has_element?(view, "[id^=spoken-rosary-female-scriptural]")
  end

  test "the voice reaching a decade moves the bead, and moving the bead moves the voice",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
    steps = script(view)

    at = Enum.find(steps, &(&1["page"] == 3))
    voice_reaches(view, at)

    assert assert_patch(view) =~ "mystery=2&step="
    refute_push_event(view, "spoken_seek", %{})

    # Reporting the prayer it is already on moves nothing.
    voice_reaches(view, at)
    refute_patched(view)

    view |> element("button[phx-click=next]") |> render_click()
    assert_push_event(view, "spoken_seek", %{screen: screen})
    assert screen == at["screen"] + 1
  end

  test "the bead follows the voice and the voice the bead", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    hail_mary =
      view
      |> script()
      |> Enum.find(&(&1["caption"] == "Hail Mary · 4 of 10" and &1["page"] == 1))

    voice_reaches(view, hail_mary)

    # The announcement, the meditation, the Our Father, then Hail Marys.
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=0&step=6")

    assert view |> element("#bead-status") |> render() =~ "Hail Mary · 4 of 10"

    render_keydown(view, "key_nav", %{"key" => " "})
    assert_push_event(view, "spoken_seek", %{screen: screen})
    assert screen == hail_mary["screen"] + 1
  end

  test "a place the voice reports from before the reader's last move is not followed",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
    steps = script(view)

    view |> element("button[phx-click=next]") |> render_click()
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=opening&step=1")
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

    assert assert_patch(view) =~ "mystery=2&step="
  end

  test "a Rosary prayed aloud is recorded as prayed aloud", %{conn: conn} do
    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing&step=999")

    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == true
  end

  test "a Rosary with no recording to play is recorded as silent", %{conn: conn} do
    put_env(:ex_aws, :access_key_id, nil)
    put_env(:ex_aws, :secret_access_key, nil)

    set = create_set("joyful", 5)

    {:ok, view, _html} =
      live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing&step=999")

    refute has_element?(view, "[phx-hook=SpokenRosary]")
    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == false
  end
end
