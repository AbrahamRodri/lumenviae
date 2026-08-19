defmodule LumenViaeWeb.Live.Admin.DashboardTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Dashboard Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  # The count sits in a span beside the label rather than inside it, so read
  # the whole health row and take its number.
  defp artwork_count(html) do
    {:ok, doc} = Floki.parse_document(html)

    row =
      doc
      |> Floki.find("div.border-b")
      |> Enum.find(&(Floki.text(&1) =~ "Sets without artwork"))

    assert row, "the dashboard has no \"Sets without artwork\" row"

    row |> Floki.find("span") |> Floki.text() |> String.trim()
  end

  test "counts the sets still waiting for a painting", %{conn: conn} do
    create_set()
    create_set()

    {:ok, _view, html} = live(conn, "/admin")

    assert html =~ "Sets without artwork"
    assert artwork_count(html) == "2"
  end

  test "the count drops as paintings are uploaded", %{conn: conn} do
    create_set()
    set = create_set()

    {:ok, _} =
      Rosary.update_meditation_set_artwork(set, %{
        "image_key" => "sets/#{set.id}/painting.jpg",
        "image_width" => 1600,
        "image_height" => 2400
      })

    {:ok, _view, html} = live(conn, "/admin")

    assert artwork_count(html) == "1"
  end

  # Counted whatever the publish gate says: a set with a painting is not
  # waiting for one, even if it still needs a description before it is served.
  test "counts a set that has a painting but no description as having artwork", %{conn: conn} do
    set = create_set()

    {:ok, _} =
      Rosary.update_meditation_set_artwork(set, %{
        "image_key" => "sets/#{set.id}/painting.jpg",
        "image_width" => 1600,
        "image_height" => 2400
      })

    {:ok, _view, html} = live(conn, "/admin")

    assert artwork_count(html) == "0"
  end
end
