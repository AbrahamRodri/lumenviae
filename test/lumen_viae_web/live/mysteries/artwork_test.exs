defmodule LumenViaeWeb.Live.Mysteries.ArtworkTest do
  @moduledoc """
  The console's artwork panels for a mystery and for the Seven Sorrows'
  card. Uploads themselves go through `ArtworkUpload`, tested on its own;
  these tests cover what the pages write.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  @details %{
    image_alt: "The angel Gabriel kneels before Mary.",
    image_artist: "Paolo de Matteis",
    image_license: "public_domain"
  }

  describe "a mystery's page" do
    setup do
      # A position of its own: (category, order) is unique.
      {:ok, mystery} =
        Rosary.create_mystery(%{name: "Artwork mystery", category: "joyful", order: 311},
          actor: admin()
        )

      %{mystery: mystery}
    end

    test "carries the artwork panel", %{conn: conn, mystery: mystery} do
      {:ok, _view, html} = live(conn, "/admin/mysteries/#{mystery.id}/edit")

      assert html =~ "Artwork"
      assert html =~ "Upload a painting"
    end

    test "saves the painting's details through the artwork action", %{
      conn: conn,
      mystery: mystery
    } do
      {:ok, view, _html} = live(conn, "/admin/mysteries/#{mystery.id}/edit")

      view
      |> form("form[phx-submit=update_artwork_meta]", %{artwork: @details})
      |> render_submit()

      {:ok, saved} = Rosary.get_mystery(mystery.id, actor: admin())
      assert {saved.image_alt, saved.image_license} == {@details.image_alt, "public_domain"}
      # Saved, not served: there is no painting yet.
      assert render(view) =~ "not served yet"
    end
  end

  describe "the Seven Sorrows' card page" do
    test "writes nothing when it is opened", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/mysteries/cards/seven_sorrows")

      assert html =~ "Seven Sorrows of Mary card"
      assert Rosary.list_category_cards!(actor: admin()) == []
    end

    test "creates the card the first time its details are saved", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/mysteries/cards/seven_sorrows")

      view
      |> form("form[phx-submit=update_artwork_meta]", %{
        artwork: %{@details | image_alt: "Mary holds her dead Son."}
      })
      |> render_submit()

      assert [card] = Rosary.list_category_cards!(actor: admin())
      assert {card.slug, card.image_alt} == {"seven_sorrows", "Mary holds her dead Son."}

      # A second save writes the same row.
      view
      |> form("form[phx-submit=update_artwork_meta]", %{artwork: %{image_artist: "Bouguereau"}})
      |> render_submit()

      assert [%{image_artist: "Bouguereau"}] = Rosary.list_category_cards!(actor: admin())
    end

    test "a Rosary's card is its first mystery's painting, and has no page", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/mysteries"}}} =
               live(conn, "/admin/mysteries/cards/joyful")

      assert {:error, {:live_redirect, %{to: "/admin/mysteries"}}} =
               live(conn, "/admin/mysteries/cards/not_a_category")
    end

    test "the mysteries list links to it", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/mysteries")
      assert html =~ "/admin/mysteries/cards/seven_sorrows"
    end
  end
end
