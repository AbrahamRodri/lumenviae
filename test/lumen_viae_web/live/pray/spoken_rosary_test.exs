defmodule LumenViaeWeb.Live.Pray.SpokenRosaryTest do
  @moduledoc """
  Praying aloud on the website: the switch, the voice, the script handed
  to the SpokenRosary hook, and the completion it records.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Ecto.Query
  import LumenViae.Test.EnvStub, only: [put_env: 3]
  import Phoenix.LiveViewTest

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completions.Completion

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
      Rosary.create_meditation_set(%{
        name: "Aloud #{System.unique_integer([:positive])}",
        category: category
      })

    for order <- 1..count do
      {:ok, mystery} =
        Rosary.create_mystery(%{
          name: "M #{System.unique_integer([:positive])}",
          category: category,
          order: System.unique_integer([:positive]),
          description: "d"
        })

      {:ok, meditation} =
        Rosary.create_meditation(%{content: "c", title: "t", mystery_id: mystery.id})

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order)
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

  test "the switch turns the spoken Rosary on and keeps it in the URL", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

    refute has_element?(view, "[phx-hook=SpokenRosary]")

    view |> element("button[phx-click=toggle_pray_aloud]") |> render_click()

    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=0&mobile=false&aloud=true")
    assert has_element?(view, "#spoken-rosary-female[phx-hook=SpokenRosary]")
    # The set's own narration player would talk over it.
    refute has_element?(view, "#audio-player")
  end

  test "the hook is handed the whole Rosary in order, with a URL for every prayer",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    steps = script(view)
    captions = Enum.map(steps, & &1["caption"])

    assert hd(captions) == "The Sign of the Cross"
    assert "Fatima Prayer" in captions
    assert List.last(captions) == "The Sign of the Cross"
    assert Enum.all?(steps, &String.contains?(&1["url"], "/voices/female/rosary/"))
    # The meditations have no narration here, so they are left out rather
    # than handed to the player as nothing to play.
    refute "Meditation" in captions
  end

  test "a Seven Sorrows set is prayed as the chaplet", %{conn: conn} do
    set = create_set("seven_sorrows", 7)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    captions = view |> script() |> Enum.map(& &1["caption"])

    assert Enum.take(captions, 2) == ["The Sign of the Cross", "Act of Contrition"]
    refute "Fatima Prayer" in captions
    assert "Hail Mary for her tears, 3 of 3" in captions
  end

  test "choosing a voice re-signs the script in that voice", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    view |> form("form[phx-change=set_voice]", %{voice: "male"}) |> render_change()

    assert has_element?(view, "#spoken-rosary-male")
    assert view |> script() |> Enum.all?(&String.contains?(&1["url"], "/voices/male/rosary/"))
  end

  test "the voice reaching a decade turns the page, and turning the page moves the voice",
       %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?aloud=true")

    view |> element("[phx-hook=SpokenRosary]") |> render_hook("spoken_at", %{decade: 2})
    assert_patch(view, "/meditation-sets/#{set.id}/pray?mystery=2&mobile=false&aloud=true")
    refute_push_event(view, "spoken_seek", %{decade: 2})

    view |> element("button[phx-click=next]") |> render_click()
    assert_push_event(view, "spoken_seek", %{decade: 3})
  end

  test "a Rosary prayed aloud is recorded as prayed aloud", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4&aloud=true")

    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == true
  end

  test "a Rosary read silently is recorded as silent", %{conn: conn} do
    set = create_set("joyful", 5)
    {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=4")

    view |> element("button[phx-click=complete]") |> render_click()

    completion = Repo.one(from c in Completion, order_by: [desc: c.id], limit: 1)
    assert completion.prayed_aloud == false
  end
end
