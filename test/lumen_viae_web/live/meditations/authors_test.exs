defmodule LumenViaeWeb.Live.Meditations.AuthorsTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_author(name \\ "Venerable Fulton J. Sheen") do
    {:ok, author} = Rosary.create_author(%{name: name})
    author
  end

  defp give_portrait(author) do
    {:ok, author} =
      Rosary.update_author_artwork(author, %{
        "image_key" => "authors/#{author.id}/8f21c4d9e0b3a7f6.jpg",
        "image_width" => 1600,
        "image_height" => 2000
      })

    author
  end

  describe "new" do
    test "creates an author and moves on to their edit page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/authors/new")

      view
      |> form("form[phx-submit=create_author]", %{author: %{name: "St. Louis de Montfort"}})
      |> render_submit()

      assert [author] = Rosary.list_authors!()
      assert author.name == "St. Louis de Montfort"
      assert_redirect(view, "/admin/authors/#{author.id}/edit")
    end

    test "shows a duplicate name beside the field", %{conn: conn} do
      create_author()
      {:ok, view, _html} = live(conn, "/admin/authors/new")

      html =
        view
        |> form("form[phx-submit=create_author]", %{
          author: %{name: "Venerable Fulton J. Sheen"}
        })
        |> render_submit()

      assert html =~ "has already been taken"
      assert length(Rosary.list_authors!()) == 1
    end
  end

  describe "edit" do
    test "renames the author", %{conn: conn} do
      author = create_author()
      {:ok, view, html} = live(conn, "/admin/authors/#{author.id}/edit")

      assert html =~ ~s(value="Venerable Fulton J. Sheen")

      html =
        view
        |> form("form[phx-submit=update_author]", %{author: %{name: "Blessed Fulton J. Sheen"}})
        |> render_submit()

      assert html =~ "Author updated"
      assert Rosary.get_author!(author.id).name == "Blessed Fulton J. Sheen"
    end

    test "saves the artwork details and says when the portrait is not served yet", %{conn: conn} do
      author = create_author() |> give_portrait()
      {:ok, view, _html} = live(conn, "/admin/authors/#{author.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_alt: "A portrait of the archbishop at his desk."}
        })
        |> render_submit()

      assert html =~ "not served yet"

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_license: "public_domain", image_source_url: "https://example.org/p"}
        })
        |> render_submit()

      assert html =~ "Portrait saved"
      refute html =~ "not served yet"

      saved = Rosary.get_author!(author.id)
      assert saved.image_alt == "A portrait of the archbishop at his desk."
      assert saved.image_license == "public_domain"
      assert saved.image_key == author.image_key
    end

    test "shows an invalid source URL beside its field and saves nothing", %{conn: conn} do
      author = create_author() |> give_portrait()
      {:ok, view, _html} = live(conn, "/admin/authors/#{author.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_artwork_meta]", %{
          artwork: %{image_alt: "A portrait.", image_source_url: "example.org/portrait"}
        })
        |> render_submit()

      assert html =~ "Failed to save the artwork details"
      assert html =~ "must start with http:// or https://"
      assert Rosary.get_author!(author.id).image_alt == nil
    end

    # A crafted post naming a managed column is the case the two artwork
    # actions exist for. The form drops the stray key and saves the rest.
    test "a posted image_key is ignored", %{conn: conn} do
      author = create_author() |> give_portrait()
      {:ok, view, _html} = live(conn, "/admin/authors/#{author.id}/edit")

      render_submit(view, "update_artwork_meta", %{
        "artwork" => %{"image_key" => "authors/999/stolen.jpg", "image_alt" => "A portrait."}
      })

      saved = Rosary.get_author!(author.id)
      assert saved.image_key == author.image_key
      assert saved.image_alt == "A portrait."
    end

    test "moving the focal point saves it and keeps the other forms current", %{conn: conn} do
      author = create_author() |> give_portrait()
      {:ok, view, _html} = live(conn, "/admin/authors/#{author.id}/edit")

      render_hook(view, "set_focal_point", %{"x" => 0.25, "y" => 0.75})
      render_click(view, "nudge_focal", %{"axis" => "y", "delta" => "0.05"})

      saved = Rosary.get_author!(author.id)
      assert saved.image_focal_x == 0.25
      assert saved.image_focal_y == 0.8

      # A rename after the focal point moved must not put the old one back.
      view
      |> form("form[phx-submit=update_author]", %{author: %{name: "Renamed"}})
      |> render_submit()

      saved = Rosary.get_author!(author.id)
      assert saved.name == "Renamed"
      assert saved.image_focal_x == 0.25
      assert saved.image_focal_y == 0.8
    end
  end

  describe "list" do
    test "deleting an author leaves their sets in place, unlinked", %{conn: conn} do
      author = create_author()
      {:ok, set} = Rosary.create_meditation_set(%{name: "Sheen", category: "joyful"})
      {:ok, set} = Rosary.update_meditation_set(set, %{author_id: author.id})
      {:ok, view, _html} = live(conn, "/admin/authors")

      html = render_click(view, "delete_author", %{"id" => to_string(author.id)})

      assert html =~ "Author deleted"
      assert Rosary.list_authors!() == []
      assert Rosary.get_meditation_set!(set.id).author_id == nil
    end
  end
end
