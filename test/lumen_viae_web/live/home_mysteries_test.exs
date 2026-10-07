defmodule LumenViaeWeb.Live.HomeMysteriesTest do
  @moduledoc """
  The home page reads today's mysteries, their fruits and every category's
  painting from the database.

  Not async: it inserts the real mystery keys (`joyful_1`...), which other
  tests insert too.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  @joyful [
    {"The Annunciation", "Humility"},
    {"The Visitation", "Charity"},
    {"The Nativity of Our Lord", "Poverty of spirit"},
    {"The Presentation in the Temple", "Obedience"},
    {"The Finding of Jesus in the Temple", "Piety"}
  ]

  setup do
    mysteries =
      for {{name, fruit}, order} <- Enum.with_index(@joyful, 1) do
        {:ok, mystery} =
          Rosary.create_mystery(
            %{name: name, fruit: fruit, category: "joyful", order: order},
            actor: admin()
          )

        mystery
      end

    %{annunciation: hd(mysteries)}
  end

  # Today moved to the next Monday, the Joyful Mysteries' day.
  defp open_on_monday(conn) do
    days_ahead = Integer.mod(1 - Date.day_of_week(Date.utc_today()), 7)
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "set_timezone", %{"offset" => -days_ahead * 24 * 60})
    view
  end

  test "today's five mysteries are the database's, each with its fruit", %{conn: conn} do
    mysteries = conn |> open_on_monday() |> element("#todays-mysteries") |> render()

    for {name, fruit} <- @joyful do
      assert mysteries =~ name
      assert mysteries =~ fruit
    end

    refute mysteries =~ "The First Joyful Mystery"
  end

  test "a category's card shows its first mystery's painting once published",
       %{conn: conn, annunciation: annunciation} do
    card = fn -> conn |> open_on_monday() |> element("#category-joyful") |> render() end

    refute card.() =~ "<img"

    {:ok, annunciation} =
      Rosary.update_mystery_artwork(
        annunciation,
        %{
          image_key: "mysteries/1/0123456789abcdef.jpg",
          image_width: 1600,
          image_height: 2400,
          image_updated_at: ~U[2026-10-04 00:00:00Z]
        },
        actor: admin()
      )

    {:ok, _} =
      Rosary.update_mystery_artwork_metadata(
        annunciation,
        %{image_alt: "The angel Gabriel kneels before Mary.", image_license: "public_domain"},
        actor: admin()
      )

    html = card.()
    assert html =~ "mysteries/1/0123456789abcdef.jpg"
    assert html =~ ~s(alt="The angel Gabriel kneels before Mary.")
  end
end
