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
      assert has_element?(view, ~s(img[src="/images/woodcuts/lamentation-durer.jpg"]))
    end

    test "an unknown category is a 404", %{conn: conn} do
      error = assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/mysteries/cheerful") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "ways to pray without a set" do
    test "offer the Scriptural Rosary and the Rosary Said Aloud", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/sorrowful")

      assert has_element?(
               view,
               ~s(a[href="/mysteries/sorrowful/pray?form=scriptural"]),
               "The Scriptural Rosary"
             )

      assert has_element?(
               view,
               ~s(a[href="/mysteries/sorrowful/pray?form=holy"]),
               "The Rosary Said Aloud"
             )
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
      assert card =~ "Honey-sweet."
      assert card =~ "St. Bernard"
      assert card =~ "1 meditation"
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
      choose(view, %{aloud: "true", voice: "male"})

      to = "/meditation-sets/#{set.id}/pray?aloud=true&voice=male"

      assert {:error, {:live_redirect, %{to: ^to}}} =
               view |> element("button", "Let one be chosen for me") |> render_click()
    end
  end

  describe "Your Rosary Today" do
    setup do
      %{set: visible_set(%{name: "A Set"})}
    end

    test "offers Audio, Counting and Voice as radio groups", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert has_element?(view, "fieldset legend", "Audio")

      assert has_element?(
               view,
               ~s(input[type=radio][name="choices[aloud]"][value=false][checked])
             )

      assert has_element?(view, "label", "Meditation only")
      assert has_element?(view, "label", "Whole Rosary aloud")

      assert has_element?(
               view,
               ~s(input[type=radio][name="choices[count]"][value=beads][checked])
             )

      assert has_element?(
               view,
               ~s(input[type=radio][name="choices[voice]"][value=female][checked])
             )

      assert has_element?(view, "label", "Male")
    end

    test "counting on the screen is carried by every link", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{count: "screen"})

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?count=screen"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=scriptural&count=screen"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=holy"]))
    end

    test "the Whole Rosary aloud drops Counting, which the voice then keeps", %{
      conn: conn,
      set: set
    } do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{count: "screen"})
      choose(view, %{aloud: "true"})

      refute has_element?(view, ~s(input[name="choices[count]"]))
      assert render(view) =~ "With the Whole Rosary, the voice moves the beads on the screen."
      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?aloud=true"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=scriptural&aloud=true"]))
    end

    test "a voice other than the default is named in the links", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{voice: "male"})

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?voice=male"]))
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=holy&voice=male"]))
      # Read in silence, the Scriptural Rosary has no voice.
      assert has_element?(view, ~s(a[href="/mysteries/joyful/pray?form=scriptural"]))
    end

    test "the Scriptural Rosary's row says it is read in silence", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      assert view |> element("li", "The Scriptural Rosary") |> render() =~
               "Read in silence · On my rosary"

      choose(view, %{aloud: "true"})

      assert view |> element("li", "The Scriptural Rosary") |> render() =~
               "Whole Rosary aloud · Female voice"
    end

    test "each change is handed to the browser to remember", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      choose(view, %{count: "screen"})

      assert_push_event(view, "store_choices", %{
        "aloud" => "false",
        "count" => "screen",
        "voice" => "female"
      })
    end

    test "the browser's saved choices are restored, and nonsense ignored", %{conn: conn, set: set} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful")

      render_hook(view, "restore_choices", %{
        "aloud" => "false",
        "count" => "screen",
        "voice" => "nobody"
      })

      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?count=screen"]))
      assert has_element?(view, ~s(input[name="choices[voice]"][value=female][checked]))

      render_hook(view, "restore_choices", %{"aloud" => "maybe", "count" => "abacus"})
      assert has_element?(view, ~s(a[href="/meditation-sets/#{set.id}/pray?count=screen"]))
    end
  end
end
