defmodule LumenViaeWeb.Live.Pray.BottomRowTest do
  @moduledoc """
  The row under Back and Next, as the apps have it: READ, VOICE, TEXT and
  MORE, four equal buttons, READ only through a mystery with a
  meditation. Each opens a sheet of its own at the foot of the screen, and
  the bar hides while one is open. Between them the sheets hold every
  setting the page offers.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  defp create_set(count \\ 5) do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Row Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    for order <- 1..count do
      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: "Row Mystery #{System.unique_integer([:positive])}",
            category: "joyful",
            order: System.unique_integer([:positive])
          },
          actor: admin()
        )

      {:ok, meditation} =
        Rosary.create_meditation(
          %{
            content: "Reading #{order}.",
            author: "St. Alphonsus Liguori",
            source: "The Glories of Mary",
            mystery_id: mystery.id
          },
          actor: admin()
        )

      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    set
  end

  defp row_labels(view) do
    view
    |> element("#prayer-sheet-row")
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find("button")
    |> Enum.map(&(&1 |> Floki.find("span") |> List.last() |> Floki.text() |> String.trim()))
  end

  describe "the row" do
    test "is READ, VOICE, TEXT and MORE through a mystery with a meditation", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=1&step=3")

      assert row_labels(view) == ["Read", "Voice", "Text", "More"]
      assert has_element?(view, "nav.prayer-bottom-nav #prayer-sheet-row.grid-cols-4")
      assert has_element?(view, "#sheet-button-read[aria-label='Read the meditation']")
    end

    test "is VOICE, TEXT and MORE where there is no meditation", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")
      assert row_labels(view) == ["Voice", "Text", "More"]
      assert has_element?(view, "#prayer-sheet-row.grid-cols-3")

      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?mystery=0")
      assert row_labels(view) == ["Voice", "Text", "More"]
    end

    test "READ cannot be opened where it is not shown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray?mystery=0")

      render_click(view, "open_sheet", %{"sheet" => "read"})
      refute has_element?(view, "#sheet-read")
      refute has_element?(view, "nav.prayer-bottom-nav[hidden]")

      render_click(view, "open_sheet", %{"sheet" => "nonsense"})
      refute has_element?(view, "nav.prayer-bottom-nav[hidden]")
    end
  end

  describe "the sheets" do
    test "each opens its own sheet, and the bar hides while it is open", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=0")

      for sheet <- ~w(read voice text more) do
        refute has_element?(view, "nav.prayer-bottom-nav[hidden]")

        view |> element("#sheet-button-#{sheet}") |> render_click()

        assert has_element?(view, "#sheet-#{sheet}[role=dialog][aria-modal=true]")
        refute has_element?(view, "#sheet-#{sheet}[hidden]")
        assert has_element?(view, "nav.prayer-bottom-nav[hidden]")
        assert has_element?(view, "#prayer-sheets[data-open=#{sheet}]")

        for other <- ~w(voice text more) -- [sheet] do
          assert has_element?(view, "#sheet-#{other}[hidden]")
        end

        view |> element("#sheet-#{sheet} button[phx-click=close_sheet]", "Done") |> render_click()

        refute has_element?(view, "nav.prayer-bottom-nav[hidden]")
        refute has_element?(view, "#prayer-sheets[data-open]")
      end
    end

    test "READ shows the whole meditation and its citation", %{conn: conn} do
      set = create_set()
      {:ok, view, html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=1&step=4")
      refute html =~ "Reading 2."

      view |> element("#sheet-button-read") |> render_click()

      sheet = view |> element("#sheet-read") |> render()
      assert sheet =~ "Reading 2."
      assert sheet =~ "St. Alphonsus Liguori"
      assert sheet =~ "The Glories of Mary"
    end

    test "READ closes when the page moves past the mysteries", %{conn: conn} do
      set = create_set(1)
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray?mystery=0&step=999")

      view |> element("#sheet-button-read") |> render_click()
      assert has_element?(view, "#sheet-read")

      render_click(view, "next", %{})

      refute has_element?(view, "#sheet-read")
      refute has_element?(view, "#prayer-sheets[data-open]")
      refute has_element?(view, "nav.prayer-bottom-nav[hidden]")
    end

    test "every setting the page offers is in one of the sheets", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = live(conn, "/meditation-sets/#{set.id}/pray")

      # VOICE: the narrator and the prayers' speed.
      assert has_element?(view, "#sheet-voice legend", "Voice")
      assert has_element?(view, "#sheet-voice button[phx-click=set_voice]")
      assert has_element?(view, "#sheet-voice #prayer-speed button[data-prayer-rate='1.3']")

      # TEXT: the size, the prayers' language, the words, the reading page
      # and the images.
      assert has_element?(view, "#sheet-text button[data-text-size='1']")
      assert has_element?(view, "#sheet-text button[data-text-size='-1']")
      assert has_element?(view, ~s(#sheet-text button[phx-value-language="la"]))
      assert has_element?(view, "#sheet-text [data-display=prayer-words][role=switch]")
      assert has_element?(view, "#sheet-text [data-display=reading-page][data-value=vellum]")
      assert has_element?(view, "#sheet-text [data-display=reading-page][data-value=night]")
      assert has_element?(view, "#sheet-text [data-display=prayer-images][data-value=off]")

      # MORE: the set and its author, how to pray, after the Rosary, Share.
      more = view |> element("#sheet-more header") |> render()
      assert more =~ set.name
      assert more =~ "The Joyful Mysteries"
      assert has_element?(view, "#sheet-more button[phx-value-form=scriptural]")
      assert has_element?(view, "#sheet-more button[phx-value-extra=memorare]")
      assert has_element?(view, "#sheet-more button[data-share]", "Share")
    end

    test "a chosen note reads in ink-light", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/mysteries/joyful/pray")

      assert has_element?(
               view,
               ~s(#sheet-text button[phx-value-language="en"][aria-pressed="true"] .text-ink-light)
             )

      refute has_element?(
               view,
               ~s(#sheet-text button[phx-value-language="la"] .text-ink-light)
             )
    end
  end
end
