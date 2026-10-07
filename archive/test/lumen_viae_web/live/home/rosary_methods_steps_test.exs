defmodule LumenViaeWeb.Live.Home.RosaryMethodsStepsTest do
  @moduledoc """
  The step-by-step guide on `/rosary-methods`: walking it with Previous and
  Next, which stop at its ends, and the step and set choices the page holds
  to the ones it has.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp open(conn) do
    {:ok, view, _html} = live(conn, "/rosary-methods")
    view
  end

  defp next(view), do: view |> element("button[phx-click=next-step]") |> render_click()
  defp prev(view), do: view |> element("button[phx-click=prev-step]") |> render_click()

  test "opens on step one, with Previous disabled", %{conn: conn} do
    view = open(conn)

    assert render(view) =~ "Step 1 of 10"
    assert has_element?(view, "button[phx-click=prev-step][disabled]")
    refute has_element?(view, "button[phx-click=next-step][disabled]")
  end

  test "Next and Previous walk the steps in order", %{conn: conn} do
    view = open(conn)

    html = next(view)
    assert html =~ "Step 2 of 10"
    assert html =~ "The Our Father"

    html = next(view)
    assert html =~ "Step 3 of 10"
    assert html =~ "Three Hail Marys"

    html = prev(view)
    assert html =~ "Step 2 of 10"
  end

  test "Next stops at the last step and is disabled there", %{conn: conn} do
    view = open(conn)

    for _ <- 1..9, do: next(view)

    html = render(view)
    assert html =~ "Step 10 of 10"
    assert html =~ "The Final Sign of the Cross"
    assert has_element?(view, "button[phx-click=next-step][disabled]")

    # A press that reaches the server anyway stays on the last step.
    assert render_click(view, "next-step", %{}) =~ "Step 10 of 10"
  end

  test "a press of Previous on the first step stays there", %{conn: conn} do
    view = open(conn)

    assert render_click(view, "prev-step", %{}) =~ "Step 1 of 10"
  end

  test "a step number outside the guide lands on its nearest end", %{conn: conn} do
    view = open(conn)

    assert render_click(view, "select-step", %{"step" => "99"}) =~ "Step 10 of 10"
    assert render_click(view, "select-step", %{"step" => "0"}) =~ "Step 1 of 10"
  end

  # The step comes from the client. Anything that is not a whole number
  # used to raise in String.to_integer/1 and take the page down.
  test "a step that is not a whole number leaves the guide where it was", %{conn: conn} do
    view = open(conn)
    next(view)
    next(view)

    for step <- ["abc", "", "2.5", "3 ", nil] do
      assert render_click(view, "select-step", %{"step" => step}) =~ "Step 3 of 10",
             "step #{inspect(step)}"
    end

    assert render_click(view, "select-step", %{}) =~ "Step 3 of 10"
    assert next(view) =~ "Step 4 of 10"
  end

  test "a set the first method does not have is ignored", %{conn: conn} do
    view = open(conn)
    view |> element("button[phx-value-set='sorrowful']") |> render_click()

    html = render_click(view, "select-method-set", %{"set" => "luminous"})

    assert html =~ "Sixth Decade"
    assert html =~ "mortal Agony in the Garden of Olives"
  end
end
