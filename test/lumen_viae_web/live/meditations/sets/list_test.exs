defmodule LumenViaeWeb.Live.Meditations.Sets.ListTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Test Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Test meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs), actor: admin())
    meditation
  end

  # A live set: it has a meditation. An empty set is hidden.
  defp create_set(attrs) do
    attrs |> create_empty_set() |> LumenViae.Test.Sets.with_meditation()
  end

  # For a test that fills the set itself, or wants it empty.
  defp create_empty_set(attrs) do
    defaults = %{name: "Test Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  test "lists sets with their meditation and narration counts", %{conn: conn} do
    mystery = create_mystery()
    filled = create_empty_set(%{name: "Filled Set"})
    create_empty_set(%{name: "Empty Set"})

    for order <- 1..5 do
      meditation = create_meditation(mystery, %{audio_url: "clip#{order}.mp3"})
      {:ok, _} = Rosary.add_meditation_to_set(filled.id, meditation.id, order, actor: admin())
    end

    # The empty set is hidden, so it is only on the list when hidden sets
    # are asked for.
    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=all")

    assert html =~ "Filled Set"
    assert html =~ "Empty Set"
    # "5 / 5" meditations for the filled set, "0 / 5" for the empty one.
    assert html =~ "5</span>"
    assert html =~ "/ 5"
  end

  test "a set with no meditations is hidden, and the list says why", %{conn: conn} do
    mystery = create_mystery()
    create_empty_set(%{name: "Just Created Set"})
    withdrawn = create_empty_set(%{name: "Withdrawn Set"})
    create_set(%{name: "Serving Set"})

    meditation = create_meditation(mystery)
    {:ok, _} = Rosary.add_meditation_to_set(withdrawn.id, meditation.id, 1, actor: admin())
    {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

    # Not on the default list, which is what the public is being served.
    {:ok, _view, html} = live(conn, "/admin/meditation-sets")
    assert html =~ "Serving Set"
    refute html =~ "Just Created Set"
    refute html =~ "Withdrawn Set"
    # The Hidden tile counts both, and says how many of each.
    assert html =~ "1 with an archived meditation, 1 with none yet"

    # Each reason has its own filter, which is where the dashboard links.
    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=empty")
    assert html =~ "Just Created Set"
    assert html =~ "This set has no meditations yet"
    refute html =~ "Withdrawn Set"
    refute html =~ "Serving Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=archived")
    assert html =~ "Withdrawn Set"
    assert html =~ "This set contains an archived meditation"
    refute html =~ "Just Created Set"
    refute html =~ "Serving Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=hidden")
    assert html =~ "Just Created Set"
    assert html =~ "Withdrawn Set"
    refute html =~ "Serving Set"
  end

  test "visibility filter separates hidden sets", %{conn: conn} do
    mystery = create_mystery()
    hidden_set = create_empty_set(%{name: "Hidden Set"})
    create_set(%{name: "Visible Set"})

    meditation = create_meditation(mystery)
    {:ok, _} = Rosary.add_meditation_to_set(hidden_set.id, meditation.id, 1, actor: admin())
    {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=hidden")
    assert html =~ "Hidden Set"
    refute html =~ "Visible Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=visible")
    assert html =~ "Visible Set"
    refute html =~ "Hidden Set"
  end

  # The default the admin asked for: the list answers "what is the public
  # being served?" until told otherwise.
  test "the list shows live sets by default, and \"all\" opts back in", %{conn: conn} do
    mystery = create_mystery()
    hidden_set = create_empty_set(%{name: "Withdrawn Set"})
    create_set(%{name: "Serving Set"})

    meditation = create_meditation(mystery)
    {:ok, _} = Rosary.add_meditation_to_set(hidden_set.id, meditation.id, 1, actor: admin())
    {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

    {:ok, _view, html} = live(conn, "/admin/meditation-sets")
    assert html =~ "Serving Set"
    refute html =~ "Withdrawn Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?visibility=all")
    assert html =~ "Serving Set"
    assert html =~ "Withdrawn Set"
  end

  # The dashboard's "Sets without artwork" row links here, so the filter it
  # links to has to exist and mean the same thing.
  test "artwork filter separates sets by what the app will draw", %{conn: conn} do
    create_set(%{name: "Bare Set"})
    illustrated = create_set(%{name: "Painted Set"})

    {:ok, _} =
      Rosary.update_meditation_set_artwork(
        illustrated,
        %{
          "image_key" => "sets/#{illustrated.id}/painting.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_alt" => "A painting",
          "image_license" => "public_domain"
        },
        actor: admin()
      )

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?artwork=missing")
    assert html =~ "Bare Set"
    refute html =~ "Painted Set"

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?artwork=served")
    assert html =~ "Painted Set"
    refute html =~ "Bare Set"
  end

  test "label filter picks out sets with no label at all", %{conn: conn} do
    create_set(%{name: "Tagged Set", labels: ["Saints"]})
    create_set(%{name: "Untagged Set"})

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?label=none")

    assert html =~ "Untagged Set"
    refute html =~ "Tagged Set"
  end

  test "label filter matches sets carrying the label", %{conn: conn} do
    create_set(%{name: "Saints Set", labels: ["Saints"]})
    create_set(%{name: "Plain Set"})

    {:ok, _view, html} = live(conn, "/admin/meditation-sets?label=Saints")

    assert html =~ "Saints Set"
    refute html =~ "Plain Set"
  end

  test "expanding a set shows its ordered meditations inline", %{conn: conn} do
    mystery = create_mystery()
    set = create_empty_set(%{name: "Expandable Set"})
    meditation = create_meditation(mystery, %{title: "Unique Expanded Title"})
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())

    {:ok, view, html} = live(conn, "/admin/meditation-sets")
    refute html =~ "Unique Expanded Title"

    html =
      view
      |> element("button[phx-click=toggle_expand][phx-value-id='#{set.id}']")
      |> render_click()

    assert html =~ "Unique Expanded Title"
  end

  test "deleting a set removes it from the list", %{conn: conn} do
    set = create_set(%{name: "Deletable Set"})

    {:ok, view, _html} = live(conn, "/admin/meditation-sets")

    html =
      view
      |> element("button[phx-click=delete_set][phx-value-id='#{set.id}']")
      |> render_click()

    refute html =~ "Deletable Set"

    assert Rosary.list_meditation_sets!(actor: admin())
           |> Enum.map(& &1.id)
           |> Enum.member?(set.id) == false
  end
end
