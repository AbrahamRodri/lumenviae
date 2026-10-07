defmodule LumenViaeWeb.Live.Pray.FormsTest do
  @moduledoc """
  The ways a Rosary is prayed on the prayer page: the Scriptural Rosary
  and the prayers alone, with or without a set; counting on the screen a
  bead at a time; the optional closing prayers; the Seven Sorrows chaplet;
  and the offer to continue where the reader left off.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  defp create_set(category \\ "joyful", count \\ 5) do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Forms Set #{System.unique_integer([:positive])}", category: category},
        actor: admin()
      )

    for order <- 1..count do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "Forms Mystery #{System.unique_integer([:positive])}",
            category: category,
            order: System.unique_integer([:positive])
          },
          actor: admin()
        )

      {:ok, meditation} =
        Rosary.create_meditation(%{content: "Reading #{order}.", mystery_id: mystery.id},
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    set
  end

  defp status(view), do: view |> element("#bead-status") |> render()

  describe "without a set" do
    test "the Scriptural Rosary is the default, a verse before each Hail Mary",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/mysteries/joyful/pray?mystery=0")

      assert html =~ "Joyful Mysteries"
      assert html =~ "The Annunciation"
      # The first verse of the Annunciation, Douay-Rheims.
      assert html =~ "Luke 1:26"
      assert html =~ "Hail Mary · 10 of 10"
    end

    test "the prayers alone have no verses and no meditation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/mysteries/sorrowful/pray?form=holy&mystery=0")

      assert html =~ "The Agony in the Garden"
      refute html =~ "Luke 22"
      refute html =~ "Read the meditation"
    end

    test "an unknown category is a 404", %{conn: conn} do
      error =
        assert_raise LumenViaeWeb.NotFoundError, fn -> live(conn, "/mysteries/cheerful/pray") end

      assert Plug.Exception.status(error) == 404
    end

    test "a form the route does not offer falls back to its default", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?form=meditation")

      view |> element("button[phx-click=toggle_panel]") |> render_click()
      assert has_element?(view, ~s(button[phx-value-form=scriptural][aria-pressed=true]))
      refute has_element?(view, "button[phx-value-form=meditation]")
    end

    test "Complete shows the Rosary offered and records nothing, having no set",
         %{conn: conn} do
      before = Rosary.count_total_completions(actor: admin())
      {:ok, view, _html} = live(conn, "/mysteries/glorious/pray?mystery=closing")

      html = view |> element("button[phx-click=complete]") |> render_click()

      assert html =~ "The Rosary is offered"
      assert Rosary.count_total_completions(actor: admin()) == before
    end
  end

  describe "a set prayed as the Scriptural Rosary" do
    test "keeps its meditation a press away", %{conn: conn} do
      set = create_set()
      path = "/meditation-sets/#{set.id}/pray"

      {:ok, view, html} = live(conn, "#{path}?mystery=0&form=scriptural")
      refute html =~ "Reading 1."

      html = view |> element("button[phx-click=toggle_meditation]") |> render_click()
      assert html =~ "Reading 1."
    end

    test "choosing the form keeps the place", %{conn: conn} do
      set = create_set()
      path = "/meditation-sets/#{set.id}/pray"
      {:ok, view, _html} = live(conn, "#{path}?mystery=2")

      view |> element("button[phx-click=toggle_panel]") |> render_click()
      view |> element("button[phx-value-form=scriptural]") |> render_click()

      assert_patch(view, "#{path}?mystery=2&form=scriptural")
    end
  end

  describe "counting on the screen" do
    test "one bead at a time, from the Sign of the Cross", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/joyful/pray?form=holy&count=screen")

      assert html =~ "In the name of the Father"
      assert status(view) =~ "The Sign of the Cross"

      render_keydown(view, "key_nav", %{"key" => " "})
      assert_patch(view, "/mysteries/joyful/pray?mystery=opening&step=1&form=holy&count=screen")
      assert status(view) =~ "The Apostles&#39; Creed"

      render_keydown(view, "key_nav", %{"key" => "ArrowUp"})
      assert status(view) =~ "The Sign of the Cross"
    end

    test "tapping the words moves on, and a decade counts its Hail Marys", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/mysteries/joyful/pray?form=holy&count=screen&mystery=0&step=1")

      assert status(view) =~ "The Our Father"

      view |> element("[phx-click=advance]") |> render_click()
      assert status(view) =~ "Hail Mary · 1 of 10"

      for _ <- 1..3, do: render_keydown(view, "key_nav", %{"key" => "ArrowDown"})
      assert status(view) =~ "Hail Mary · 4 of 10"
      assert has_element?(view, "#bead-status[aria-live=polite]")
    end

    test "the Scriptural Rosary's verse is on its Hail Mary's bead", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/joyful/pray?count=screen&mystery=0&step=2")

      assert status(view) =~ "Hail Mary · 1 of 10"
      assert html =~ "Luke 1:26"
      assert html =~ "Hail Mary, full of grace"
    end

    test "the last bead of a decade leads to the next decade", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/mysteries/joyful/pray?form=holy&count=screen&mystery=0&step=13")

      assert status(view) =~ "The Fatima Prayer"

      view |> element("button[phx-click=next]") |> render_click()
      assert_patch(view, "/mysteries/joyful/pray?mystery=1&step=0&form=holy&count=screen")
      assert render(view) =~ "The Visitation"
    end

    test "the end is a press of Complete, not another key", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/mysteries/joyful/pray?form=holy&count=screen&mystery=closing&step=99")

      assert status(view) =~ "The Sign of the Cross"
      assert has_element?(view, "button[phx-click=complete]")

      render_keydown(view, "key_nav", %{"key" => "Enter"})
      refute_patched(view)
    end

    test "switching the counting keeps the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?mystery=3")

      view |> element("button[phx-click=toggle_panel]") |> render_click()
      view |> element("button[phx-value-count=screen]") |> render_click()

      assert_patch(view, "/mysteries/joyful/pray?mystery=3&step=0&count=screen")
    end
  end

  describe "the closing prayers" do
    test "the optional prayers are added after the Rosary, in the app's order",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/joyful/pray?form=holy&mystery=closing")

      refute html =~ "Remember, O most gracious Virgin Mary"

      view |> element("button[phx-click=toggle_panel]") |> render_click()
      view |> element("button[phx-value-extra=st_michael]") |> render_click()
      html = view |> element("button[phx-value-extra=memorare]") |> render_click()

      assert_push_event(view, "prayer:extras", %{extras: ["memorare", "st_michael"]})
      assert html =~ "Remember, O most gracious Virgin Mary"
      assert html =~ "Saint Michael the Archangel"

      [memorare, michael] =
        Enum.map(["Remember, O most gracious", "Saint Michael the Archangel"], fn words ->
          :binary.match(html, words) |> elem(0)
        end)

      assert memorare < michael
    end

    test "a browser's earlier choice is restored by the hook", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?form=holy&mystery=closing")

      view
      |> element("#prayer-memory")
      |> render_hook("restore_extras", %{"extras" => ["holy_father", "nonsense"]})

      assert render(view) =~ "For the Pope&#39;s intentions"
    end

    test "the chaplet offers none", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/seven_sorrows/pray")

      view |> element("button[phx-click=toggle_panel]") |> render_click()
      refute has_element?(view, "button[phx-click=toggle_extra]")
    end
  end

  describe "the Seven Sorrows chaplet" do
    test "opens with the Act of Contrition and closes on her tears", %{conn: conn} do
      {:ok, view, html} = live(conn, "/mysteries/seven_sorrows/pray?form=holy")

      assert html =~ "The Act of Contrition"
      assert html =~ "O my God, I am heartily sorry"
      refute html =~ "The Apostles&#39; Creed"

      html = view |> element("button[phx-click=go_to][phx-value-page='1']") |> render_click()
      assert html =~ "The First Sorrow of Mary"
      assert html =~ "Seven Hail Marys"
      refute html =~ "Fatima"
      assert html =~ "Sorrow I of VII"

      {:ok, _view, html} = live(conn, "/mysteries/seven_sorrows/pray?form=holy&mystery=closing")
      assert html =~ "In honor of her tears"
      assert html =~ "Pray for us, O most sorrowful Virgin"
    end

    test "counted on the screen, a sorrow is seven Hail Marys", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/mysteries/seven_sorrows/pray?form=holy&count=screen&mystery=0&step=8")

      assert status(view) =~ "Hail Mary · 7 of 7"

      view |> element("button[phx-click=next]") |> render_click()
      assert status(view) =~ "The Glory Be"
    end

    test "a completed chaplet is offered as the Seven Sorrows", %{conn: conn} do
      set = create_set("seven_sorrows", 7)
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=closing")

      assert view |> element("button[phx-click=complete]") |> render_click() =~
               "The Seven Sorrows are offered"
    end
  end

  describe "continue where you left off" do
    test "a place saved in this browser is offered on arrival", %{conn: conn} do
      set = create_set()
      path = "/meditation-sets/#{set.id}/pray"
      {:ok, view, _html} = live(conn, path)

      view
      |> element("#prayer-memory")
      |> render_hook("resume_available", %{"mystery" => "2", "step" => 0, "count" => "beads"})

      assert has_element?(view, "#resume-banner", "The Third Joyful Mystery")

      view |> element("button[phx-click=resume]") |> render_click()
      assert_patch(view, "#{path}?mystery=2")
      refute has_element?(view, "#resume-banner")
    end

    test "with a bead, counting on the screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?form=holy")

      view
      |> element("#prayer-memory")
      |> render_hook("resume_available", %{"mystery" => "1", "step" => 4, "count" => "screen"})

      assert has_element?(view, "#resume-banner", "Hail Mary · 3 of 10")

      view |> element("button[phx-click=resume]") |> render_click()
      assert_patch(view, "/mysteries/joyful/pray?mystery=1&step=4&form=holy&count=screen")
    end

    test "is not offered to a link that names a place", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=1")

      view
      |> element("#prayer-memory")
      |> render_hook("resume_available", %{"mystery" => "3", "step" => 0, "count" => "beads"})

      refute has_element?(view, "#resume-banner")
    end

    test "can be declined", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

      view
      |> element("#prayer-memory")
      |> render_hook("resume_available", %{
        "mystery" => "closing",
        "step" => 0,
        "count" => "beads"
      })

      view |> element("button[phx-click=dismiss_resume]") |> render_click()
      refute has_element?(view, "#resume-banner")
    end
  end

  test "the page carries its hooks and a text size control", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

    assert has_element?(view, "#prayer[phx-hook=PrayerSurface][data-count=beads]")

    assert has_element?(
             view,
             ~s(#prayer-memory[phx-hook=PrayerMemory][data-key="mysteries:joyful:scriptural"])
           )

    view |> element("button[phx-click=toggle_panel]") |> render_click()
    assert has_element?(view, "button[data-text-size='1']", "Larger text")
    assert has_element?(view, "button[data-text-size='-1']", "Smaller text")
  end
end
