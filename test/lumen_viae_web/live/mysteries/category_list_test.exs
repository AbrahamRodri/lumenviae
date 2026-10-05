defmodule LumenViaeWeb.Live.Mysteries.CategoryListTest do
  @moduledoc """
  `/mysteries/:category` is where a visitor picks the set they will pray:
  only the sets the public may see, in that category, each a door into
  `/meditation-sets/:id/pray`, with "Divine Providence" choosing one for
  them.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViae.Test.Sets

  defp create_set(attrs) do
    {:ok, set} =
      Rosary.create_meditation_set(
        Map.merge(
          %{name: "Set #{System.unique_integer([:positive])}", category: "joyful"},
          attrs
        ),
        actor: admin()
      )

    set
  end

  defp visible_set(attrs, meditation_attrs \\ %{}) do
    attrs |> create_set() |> Sets.with_meditation(meditation_attrs)
  end

  describe "the page for a category" do
    for {category, title, days} <- [
          {"joyful", "The Joyful Mysteries", "Mondays and Thursdays"},
          {"sorrowful", "The Sorrowful Mysteries", "Tuesdays and Fridays"},
          {"glorious", "The Glorious Mysteries", "Wednesdays, Saturdays, and Sundays"},
          {"luminous", "The Luminous Mysteries", "Thursdays in the modern schedule"},
          {"seven_sorrows", "The Seven Sorrows of Mary", "Fridays in Lent and September 15th"}
        ] do
      test "#{category} names its mysteries and the days they are prayed", %{conn: conn} do
        {:ok, view, html} = live(conn, "/mysteries/#{unquote(category)}")

        assert html =~ unquote(title)
        assert html =~ unquote(days)
        assert page_title(view) =~ unquote(title)
      end
    end

    test "an unknown category is a 404", %{conn: conn} do
      error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/mysteries/cheerful") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "the sets offered" do
    test "lists the visible sets of that category, each linking to its prayer", %{conn: conn} do
      set = visible_set(%{name: "Meditations of St. Bernard", description: "Honey-sweet."})

      {:ok, view, html} = live(conn, "/mysteries/joyful")

      assert html =~ "Choose Your Meditations"
      assert html =~ "Meditations of St. Bernard"
      assert html =~ "Honey-sweet."
      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray"]))
    end

    test "leaves out sets of other categories", %{conn: conn} do
      visible_set(%{name: "A Sorrowful Set", category: "sorrowful"})
      visible_set(%{name: "A Joyful Set"})

      {:ok, _view, html} = live(conn, "/mysteries/joyful")

      assert html =~ "A Joyful Set"
      refute html =~ "A Sorrowful Set"
    end

    test "leaves out a set with no meditations yet", %{conn: conn} do
      create_set(%{name: "Still Being Curated"})
      visible_set(%{name: "Ready To Pray"})

      {:ok, _view, html} = live(conn, "/mysteries/joyful")

      assert html =~ "Ready To Pray"
      refute html =~ "Still Being Curated"
    end

    test "leaves out a set holding an archived meditation", %{conn: conn} do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "The Visitation",
            category: "joyful",
            order: System.unique_integer([:positive])
          },
          actor: admin()
        )

      {:ok, meditation} =
        Rosary.create_meditation(%{content: "Withdrawn.", mystery_id: mystery.id}, actor: admin())

      set = create_set(%{name: "Withdrawn Set"})
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())
      {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

      {:ok, _view, html} = live(conn, "/mysteries/joyful")

      refute html =~ "Withdrawn Set"
    end

    test "marks only the sets that have narration as guided audio", %{conn: conn} do
      narrated = visible_set(%{name: "Narrated"}, %{audio_url: "narrated.mp3"})
      silent = visible_set(%{name: "Silent"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert view
             |> element(~s(a[href="/meditation-sets/#{narrated.id}/pray"]))
             |> render() =~ "Guided Audio"

      refute view
             |> element(~s(a[href="/meditation-sets/#{silent.id}/pray"]))
             |> render() =~ "Guided Audio"
    end

    test "says so, and points to the Scriptures, when there is nothing to pray yet",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/luminous")

      assert html =~ "No meditation sets are available yet for The Luminous Mysteries"
      refute html =~ "Divine Providence"
      assert has_element?(view, ~s(a[href="/mysteries"]), "Read the Scriptures")
    end
  end

  describe "Divine Providence" do
    test "takes the visitor into one of the category's sets", %{conn: conn} do
      set = visible_set(%{name: "The Only Choice"})
      visible_set(%{name: "Not This Category", category: "glorious"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      to = "/meditation-sets/#{set.id}/pray"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("button", "Divine Providence") |> render_click()
    end
  end
end
