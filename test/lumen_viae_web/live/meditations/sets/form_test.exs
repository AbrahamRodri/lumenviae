defmodule LumenViaeWeb.Live.Meditations.Sets.FormTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp create_meditation(attrs \\ %{}) do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(Map.merge(%{content: "Text.", mystery_id: mystery.id}, attrs),
        actor: admin()
      )

    meditation
  end

  defp give_painting(set) do
    {:ok, set} =
      Rosary.update_meditation_set_artwork(
        set,
        %{
          "image_key" => "sets/#{set.id}/8f21c4d9e0b3a7f6.jpg",
          "image_width" => 1600,
          "image_height" => 2400
        },
        actor: admin()
      )

    set
  end

  describe "new" do
    test "creates a set and moves on to its edit page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/new")

      view
      |> form("form[phx-submit=create_meditation_set]", %{
        meditation_set: %{
          name: "St. Louis de Montfort",
          category: "seven_sorrows",
          description: "From The Secret of the Rosary."
        }
      })
      |> render_submit()

      assert [set] = Rosary.list_meditation_sets!(actor: admin())
      assert set.name == "St. Louis de Montfort"
      assert set.category == "seven_sorrows"
      assert set.description == "From The Secret of the Rosary."
      assert set.labels == []

      assert_redirect(view, "/admin/meditation-sets/#{set.id}/edit")
    end

    test "keeps what was typed when the set is refused", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/new")

      html =
        render_submit(view, "create_meditation_set", %{
          "meditation_set" => %{"name" => "A set with no category", "category" => ""}
        })

      assert html =~ "Failed to create meditation set"
      assert html =~ "is required"
      assert html =~ ~s(value="A set with no category")
      assert Rosary.list_meditation_sets!(actor: admin()) == []
    end
  end

  describe "edit: set details" do
    test "saves the details, the linked author and the byline", %{conn: conn} do
      {:ok, author} = Rosary.create_author(%{name: "St. Alphonsus Liguori"}, actor: admin())
      set = create_set()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_meditation_set]", %{
          meditation_set: %{
            name: "Liguori",
            category: "sorrowful",
            author_id: author.id,
            author: "St. Alphonsus Liguori",
            source: "The Glories of Mary"
          }
        })
        |> render_submit()

      assert html =~ "Meditation set updated successfully"

      saved = Rosary.get_meditation_set!(set.id, actor: admin())
      assert saved.name == "Liguori"
      assert saved.category == "sorrowful"
      assert saved.author_id == author.id
      assert saved.author == "St. Alphonsus Liguori"
      assert saved.source == "The Glories of Mary"
    end

    test "unlinks the author when None is chosen", %{conn: conn} do
      {:ok, author} = Rosary.create_author(%{name: "St. Alphonsus Liguori"}, actor: admin())
      set = create_set(%{author_id: author.id})
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      view
      |> form("form[phx-submit=update_meditation_set]", %{meditation_set: %{author_id: ""}})
      |> render_submit()

      assert Rosary.get_meditation_set!(set.id, actor: admin()).author_id == nil
    end

    test "a set that does not exist is a 404", %{conn: conn} do
      error =
        assert_raise Ash.Error.Invalid, fn -> live(conn, "/admin/meditation-sets/0/edit") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "edit: labels" do
    test "adds, reorders and removes labels, each saved at once", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_click(view, "add_label", %{"label" => "Saints"})
      render_click(view, "add_label", %{"label" => "Contemplative"})

      assert Rosary.get_meditation_set!(set.id, actor: admin()).labels == [
               "Saints",
               "Contemplative"
             ]

      render_click(view, "move_label", %{"label" => "Contemplative", "direction" => "up"})

      assert Rosary.get_meditation_set!(set.id, actor: admin()).labels == [
               "Contemplative",
               "Saints"
             ]

      render_click(view, "remove_label", %{"label" => "Contemplative"})
      assert Rosary.get_meditation_set!(set.id, actor: admin()).labels == ["Saints"]
    end

    test "refuses a label outside the vocabulary", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html = render_click(view, "add_label", %{"label" => "Invented"})

      assert html =~ "Failed to update labels"
      assert Rosary.get_meditation_set!(set.id, actor: admin()).labels == []
    end

    # Each form holds the set it was built from. If the details form were
    # left holding the copy from before the label change, saving it would
    # hand that copy back and the labels just added would vanish from the
    # page until a reload.
    test "a details save after a label change keeps the labels", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_click(view, "add_label", %{"label" => "Saints"})

      html =
        view
        |> form("form[phx-submit=update_meditation_set]", %{meditation_set: %{name: "Renamed"}})
        |> render_submit()

      saved = Rosary.get_meditation_set!(set.id, actor: admin())
      assert saved.name == "Renamed"
      assert saved.labels == ["Saints"]

      # And the page still shows the label as one that can be removed.
      assert html =~ ~s(phx-click="remove_label")
    end
  end

  describe "edit: meditations" do
    test "adds a meditation at a position and removes it again", %{conn: conn} do
      set = create_set()
      first = create_meditation(%{title: "Prayed first"})
      second = create_meditation(%{title: "Prayed second"})
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_submit(view, "add_to_set", %{"meditation_id" => to_string(second.id), "order" => "2"})

      render_submit(view, "add_to_set", %{"meditation_id" => to_string(first.id), "order" => "1"})

      assert set.id |> Rosary.list_meditations_in_set(actor: admin()) |> Enum.map(& &1.title) ==
               ["Prayed first", "Prayed second"]

      html = render_click(view, "remove_from_set", %{"meditation_id" => to_string(first.id)})

      assert html =~ "Meditation removed from set"

      assert set.id |> Rosary.list_meditations_in_set(actor: admin()) |> Enum.map(& &1.title) == [
               "Prayed second"
             ]
    end

    test "refuses a position that is already taken", %{conn: conn} do
      set = create_set()
      {:ok, _} = Rosary.add_meditation_to_set(set.id, create_meditation().id, 1, actor: admin())
      other = create_meditation()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html =
        render_submit(view, "add_to_set", %{
          "meditation_id" => to_string(other.id),
          "order" => "1"
        })

      assert html =~ "Failed to add meditation to set"
      assert length(Rosary.list_meditations_in_set(set.id, actor: admin())) == 1
    end

    test "warns that an archived meditation is hiding the set", %{conn: conn} do
      set = create_set()
      meditation = create_meditation()
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())
      {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

      {:ok, _view, html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      assert html =~ "This set contains an archived meditation"
    end
  end

  describe "edit: artwork" do
    test "saves the details and says when the painting is not served yet", %{conn: conn} do
      set = create_set() |> give_painting()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_alt: "The angel kneels before the Virgin."}
        })
        |> render_submit()

      assert html =~ "not served yet"

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_license: "public_domain", image_artist: "Fra Angelico"}
        })
        |> render_submit()

      assert html =~ "Artwork saved"
      refute html =~ "not served yet"

      saved = Rosary.get_meditation_set!(set.id, actor: admin())
      assert saved.image_alt == "The angel kneels before the Virgin."
      assert saved.image_license == "public_domain"
      assert saved.image_artist == "Fra Angelico"
      assert saved.image_key == set.image_key
    end

    test "shows an invalid source URL beside its field", %{conn: conn} do
      set = create_set() |> give_painting()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_source_url: "metmuseum.org"}
        })
        |> render_submit()

      assert html =~ "Failed to save the artwork details"
      assert html =~ "must start with http:// or https://"
    end

    test "a posted image_key is ignored", %{conn: conn} do
      set = create_set() |> give_painting()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_submit(view, "update_artwork_meta", %{
        "artwork" => %{"image_key" => "sets/999/stolen.jpg", "image_alt" => "A painting."}
      })

      saved = Rosary.get_meditation_set!(set.id, actor: admin())
      assert saved.image_key == set.image_key
      assert saved.image_alt == "A painting."
    end

    test "moving the focal point is saved and survives a later details save", %{conn: conn} do
      set = create_set() |> give_painting()
      {:ok, view, _html} = live(conn, "/admin/meditation-sets/#{set.id}/edit")

      render_hook(view, "set_focal_point", %{"x" => 0.5, "y" => 0.24})
      render_click(view, "nudge_focal", %{"axis" => "x", "delta" => "-0.1"})

      view
      |> form("form[phx-submit=update_meditation_set]", %{meditation_set: %{name: "Renamed"}})
      |> render_submit()

      view
      |> form("form[phx-submit=update_artwork_meta]", %{artwork: %{image_title: "The Fall"}})
      |> render_submit()

      saved = Rosary.get_meditation_set!(set.id, actor: admin())
      assert saved.name == "Renamed"
      assert saved.image_title == "The Fall"
      assert saved.image_focal_x == 0.4
      assert saved.image_focal_y == 0.24
    end
  end
end
