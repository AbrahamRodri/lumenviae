defmodule LumenViaeWeb.Live.Mysteries.CategoryListTest do
  @moduledoc """
  `/mysteries/:category` is where a visitor chooses how to pray one
  category: its header (painting, days, mysteries and fruits), the two
  ways to pray it without a set, the shelf of its visible sets with
  filters and Divine Providence, and the "Your Rosary Today" choices that
  every Pray link carries.
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

  defp choose(view, choices) do
    view |> form("#rosary-choices", choices: choices) |> render_change()
  end

  describe "the header" do
    for {category, title, days} <- [
          {"joyful", "The Joyful Mysteries", "Monday, Thursday, Sundays of Advent"},
          {"sorrowful", "The Sorrowful Mysteries", "Tuesday, Friday, Sundays of Lent"},
          {"glorious", "The Glorious Mysteries", "Wednesday, Saturday, Sunday"},
          {"luminous", "The Luminous Mysteries", "Any day you choose"},
          {"seven_sorrows", "The Seven Sorrows of Mary",
           "Fridays, and on her feast, September 15"}
        ] do
      test "#{category} names itself and the days it is prayed", %{conn: conn} do
        {:ok, view, html} = live(conn, "/mysteries/#{unquote(category)}")

        assert html =~ unquote(title)
        assert view |> element("[data-role=days]") |> render() =~ unquote(days)
        assert page_title(view) =~ unquote(title)
        assert has_element?(view, "h1", unquote(title))
      end
    end

    test "the Seven Sorrows list seven sorrows, with their painting", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/seven_sorrows")

      assert has_element?(view, "h2#mysteries-heading", "The Seven Sorrows")
      assert html =~ "The First Sorrow of Mary"
      assert html =~ "The Seventh Sorrow of Mary"
      # The card's painting is the app's Pieta, until one is uploaded.
      assert has_element?(view, ~s(img[src="/images/paintings/seven_sorrows_pieta.jpg"]))
    end

    test "an unknown category is a 404", %{conn: conn} do
      error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/mysteries/cheerful") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "ways to pray without a set" do
    test "offer the Scriptural Rosary and No meditation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/sorrowful")

      assert has_element?(
               view,
               ~s(a[href="/mysteries/sorrowful/pray?form=scriptural"]),
               "The Scriptural Rosary"
             )

      assert has_element?(
               view,
               ~s(a[href="/mysteries/sorrowful/pray?form=holy"]),
               "No meditation"
             )

      refute render(view) =~ "Audio Rosary"
    end

    test "are offered even when the category has no sets", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/luminous")

      assert html =~ "No meditation sets are available yet for The Luminous Mysteries"
      refute has_element?(view, "button", "Let one be chosen for me")
      assert has_element?(view, ~s(a[href="/mysteries/luminous/pray?form=scriptural"]))
    end
  end

  describe "the sets offered" do
    test "lists the visible sets of that category, each linking to its prayer", %{conn: conn} do
      set =
        visible_set(%{
          name: "Meditations of St. Bernard",
          description: "Honey-sweet.",
          author: "St. Bernard",
          labels: ["Saints", "Considerations"]
        })

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      card = view |> element("#set-#{set.id}") |> render()
      assert card =~ "Meditations of St. Bernard"
      # A tile is the app's: name, byline and kinds, not the description.
      refute card =~ "Honey-sweet."
      assert card =~ "St. Bernard"
      # Every set has its five, so the count is not shown.
      refute card =~ "1 meditation"
      assert card =~ "Saints · Reflections"
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
            order: 2_000 + System.unique_integer([:positive])
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

    test "marks only the sets that have narration", %{conn: conn} do
      narrated = visible_set(%{name: "Narrated"}, %{audio_url: "narrated.mp3"})
      silent = visible_set(%{name: "Silent"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert view |> element("#set-#{narrated.id}") |> render() =~ "Narrated"
      refute view |> element("#set-#{silent.id}") |> render() =~ "Narrated"
    end
  end

  describe "a set's byline" do
    test "is left off a set already named for its author", %{conn: conn} do
      set =
        visible_set(%{
          name: "Venerable Fulton J. Sheen",
          author: "Archbishop Fulton J. Sheen"
        })

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      refute view |> element("#set-#{set.id}") |> render() =~ "Archbishop"
    end

    test "stays on a set named for something else", %{conn: conn} do
      set = visible_set(%{name: "Inside the Scene II", author: "Pope St. John Paul II"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert view |> element("#set-#{set.id}") |> render() =~ "Pope St. John Paul II"
    end

    test "compares whole words, leaving out titles and numerals, in any case" do
      named? = &LumenViaeWeb.Live.Mysteries.CategoryList.Shelf.named_for_author?/2

      assert named?.("Venerable Fulton J. Sheen", "Archbishop Fulton J. Sheen")
      assert named?.("meditations of st. bernard", "St. Bernard")
      assert named?.("John Paul II on the Rosary", "Pope St. John Paul II")
      refute named?.("Inside the Scene II", "Pope St. John Paul II")
      refute named?.("Sheen's Favourite Prayers", "Archbishop Fulton J. Sheen")
      refute named?.("On Detachment", "St. Alphonsus Liguori")
      assert named?.("Pope John XXIII on the Rosary", "Pope St. John XXIII")
      # A word made of numeral letters is still a word of the name.
      refute named?.("Lucy on the Rosary", "Sister Lucy Civil")
      refute named?.("Lucy on the Rosary", "Sister Lucy Ill")
    end
  end

  describe "the shelf's filters" do
    setup do
      saints = visible_set(%{name: "Of The Saints", labels: ["Saints", "Considerations"]})
      scene = visible_set(%{name: "Inside It", labels: ["Contemplative"]}, %{audio_url: "a.mp3"})
      %{saints: saints, scene: scene}
    end

    test "offer only the kinds the shelf carries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert has_element?(view, ~s(button[phx-value-kind="Saints"]), "Saints")
      assert has_element?(view, ~s(button[phx-value-kind="Contemplative"]), "Inside the Scene")
      refute has_element?(view, ~s(button[phx-value-kind="Intentions"]))
    end

    test "a kind narrows the shelf, and lives in the URL", %{conn: conn} = context do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      view |> element(~s(button[phx-value-kind="Saints"])) |> render_click()

      assert_patch(view, "/mysteries/joyful?kinds=Saints")
      assert has_element?(view, ~s(button[phx-value-kind="Saints"][aria-pressed="true"]))
      assert has_element?(view, "#set-#{context.saints.id}")
      refute has_element?(view, "#set-#{context.scene.id}")
      assert render(view) =~ "Showing 1 of 2 sets."
    end

    test "kinds combine: a set must carry every one", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/joyful?kinds=Saints,Contemplative")

      assert html =~ "No meditations match all of those kinds."

      view |> element("p button", "Clear filters") |> render_click()
      assert_patch(view, "/mysteries/joyful")
    end

    test "narrated only leaves out the silent sets", %{conn: conn} = context do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      view |> element("button", "Narrated only") |> render_click()

      assert_patch(view, "/mysteries/joyful?narrated=true")
      assert has_element?(view, "#set-#{context.scene.id}")
      refute has_element?(view, "#set-#{context.saints.id}")
    end

    test "an unknown kind in the URL is ignored", %{conn: conn} = context do
      {:ok, view, _html} = live(conn, "/mysteries/joyful?kinds=Cheerful")

      assert has_element?(view, "#set-#{context.saints.id}")
      assert has_element?(view, "#set-#{context.scene.id}")
    end
  end

  describe "Divine Providence" do
    test "takes the visitor into one of the category's sets", %{conn: conn} do
      set = visible_set(%{name: "The Only Choice"})
      visible_set(%{name: "Not This Category", category: "glorious"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      to = "/meditation-sets/#{set.id}/pray"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("button", "Let one be chosen for me") |> render_click()
    end

    test "chooses among the sets the filters show, with the visitor's choices", %{conn: conn} do
      set = visible_set(%{name: "Narrated", labels: ["Saints"]}, %{audio_url: "a.mp3"})
      visible_set(%{name: "Silent"})

      {:ok, view, _html} = live(conn, "/mysteries/joyful?narrated=true")
      choose(view, %{voice: "male"})

      to = "/meditation-sets/#{set.id}/pray?voice=male"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("button", "Let one be chosen for me") |> render_click()
    end
  end

  describe "Your Rosary Today" do
    setup do
      %{set: visible_set(%{name: "A Set"})}
    end

    test "says in one line which voice is heard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      summary = fn -> view |> element("#choices-summary") |> render() end
      voice = LumenViae.Rosary.Voices.default().name

      assert summary.() =~ "#{voice} voice"

      choose(view, %{voice: "male"})
      assert summary.() =~ "Male voice"
    end

    test "offers only the voice, as a radio group", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/joyful")

      refute has_element?(view, "fieldset legend", "Audio")
      refute has_element?(view, "fieldset legend", "Counting")
      refute has_element?(view, ~s(input[name="choices[aloud]"]))
      refute has_element?(view, ~s(input[name="choices[count]"]))
      refute html =~ "Meditation only"
      refute html =~ "Whole Rosary read to you"

      assert has_element?(view, "fieldset legend", "Voice")

      assert has_element?(
               view,
               ~s(input[type=radio][name="choices[voice]"][value=female][checked])
             )

      assert has_element?(view, "label", "Male")
    end

    test "links carry neither aloud nor count", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=scriptural"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=holy"]))
    end

    test "a voice other than the default is named in every link", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{voice: "male"})

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?voice=male"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=holy&voice=male"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=scriptural&voice=male"]))
    end

    test "each change is handed to the browser to remember", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{voice: "male"})

      assert_push_event(view, "store_choices", %{"voice" => "male"} = stored)
      assert Map.keys(stored) == ["voice"]
    end

    test "the browser's saved voice is restored, and nonsense ignored", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      render_hook(view, "restore_choices", %{"voice" => "male"})
      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?voice=male"]))

      render_hook(view, "restore_choices", %{"voice" => "nobody"})
      assert has_element?(view, ~s(input[name="choices[voice]"][value=male][checked]))
    end

    test "an older saved copy with aloud and count is ignored", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      render_hook(view, "restore_choices", %{
        "aloud" => "true",
        "count" => "screen",
        "voice" => "male"
      })

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?voice=male"]))
      refute render(view) =~ "aloud="
      refute render(view) =~ "count="
    end
  end
end
