defmodule LumenViaeWeb.Live.Pray.CraftedInputTest do
  @moduledoc """
  The prayer page answers whatever a client sends it without falling over.
  A URL or an event payload is the client's to write: a list where a
  number belongs, a map from a damaged localStorage value, a key left out,
  an id no row could have. Each is either read as the nearest sensible
  thing or ignored; none of them may crash the LiveView, which would put
  the reader back at the start of the Rosary.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @path "/mysteries/joyful/pray"

  describe "the URL" do
    test "a step that is not a string is the first bead", %{conn: conn} do
      for query <- ["count=screen&step[]=1", "count=screen&step[a]=1"] do
        {:ok, view, _html} = live(conn, "#{@path}?#{query}")
        assert has_element?(view, "#bead-0")
      end
    end

    test "a set id no row could have is a 404, not a 500", %{conn: conn} do
      for id <- ["99999999999999999999", "-1", "abc"] do
        assert_error_sent :not_found, fn -> get(conn, "/meditation-sets/#{id}/pray") end
      end
    end
  end

  describe "event payloads" do
    test "an event missing its key is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      for event <- ~w(go_to set_voice set_form toggle_extra set_language set_count) do
        assert render_click(view, event, %{}) =~ "In the name of the Father"
      end
    end

    test "a page that is not a string or a number is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      for page <- [%{"a" => 1}, [1, 2], [999_999_999], nil] do
        assert render_click(view, "go_to", %{"page" => page}) =~ "In the name of the Father"
      end
    end

    test "a page given as a number is followed", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)
      render_click(view, "go_to", %{"page" => 1})

      assert_patch(view, "#{@path}?mystery=0")
    end

    test "a damaged saved place is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      for saved <- [
            %{"mystery" => %{"a" => 1}},
            %{"mystery" => [1]},
            %{"mystery" => "1", "step" => %{"a" => 1}},
            %{"mystery" => "1", "step" => [1], "count" => "screen"}
          ] do
        render_hook(view, "resume_available", saved)
        assert render(view) =~ "In the name of the Father"
      end
    end

    test "a saved place given as numbers is still offered", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      assert render_hook(view, "resume_available", %{"mystery" => 2, "step" => 0}) =~
               "Continue where you left off"
    end
  end

  describe "Complete" do
    test "is refused before the end of the Rosary", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      html = render_click(view, "complete", %{})

      refute html =~ "The Rosary is offered"
      refute has_element?(view, "#prayer-complete")
    end

    test "is accepted at the end", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@path}?mystery=closing")

      view |> element("button[phx-click=complete]") |> render_click()
      assert has_element?(view, "#prayer-complete")
    end

    test "counting on the screen, is accepted only on the last bead", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@path}?mystery=closing&count=screen")

      render_click(view, "complete", %{})
      refute has_element?(view, "#prayer-complete")
    end
  end
end
