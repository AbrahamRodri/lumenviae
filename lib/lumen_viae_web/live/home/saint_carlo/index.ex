defmodule LumenViaeWeb.Live.Home.SaintCarlo.Index do
  @moduledoc """
  St. Carlo Acutis - the first millennial saint: his life, his devotion to
  the Eucharist and the Rosary, and why Lumen Viae looks to him as patron.
  """
  use LumenViaeWeb, :live_view

  embed_templates "_partials/*"

  @moments [
    %{
      id: "birth",
      year: "1991",
      label: "London",
      title: "Born in London, raised in Milan",
      text:
        "Carlo Acutis is born in London on May 3, 1991, to Italian parents, and baptized there before the family returns to Milan. He grows up an ordinary boy of his generation: friends, soccer, video games, and an early gift for computers."
    },
    %{
      id: "communion",
      year: "1998",
      label: "First Communion",
      title: "The Eucharist becomes his highway",
      text:
        "At the age of seven, Carlo receives his First Holy Communion and from that day resolves never to miss daily Mass. He prays the Rosary every day, makes a weekly confession, and spends time before the tabernacle, saying that the Eucharist is his highway to heaven."
    },
    %{
      id: "exhibition",
      year: "2004",
      label: "The Exhibition",
      title: "Cataloguing the miracles of God",
      text:
        "A self-taught programmer, Carlo spends his teenage years building a website and exhibition documenting the Eucharistic miracles of the world and the recognized apparitions of Our Lady. The exhibition opens in Rome on October 4, 2006, and has since traveled to thousands of parishes on five continents."
    },
    %{
      id: "death",
      year: "2006",
      label: "Monza",
      title: "An offering freely made",
      text:
        "Struck suddenly by acute leukemia, Carlo offers his sufferings for the Pope and for the Church. He dies at Monza on October 12, 2006, at fifteen years old, telling his mother not to be afraid. His feast is kept on October 12."
    },
    %{
      id: "assisi",
      year: "2019",
      label: "Assisi",
      title: "At rest in the city of St. Francis",
      text:
        "In April 2019 his body is transferred to the Sanctuary of the Spoliation in Assisi, the city of the saint he loved for his poverty of spirit. There he lies in his jeans and sneakers, visited by millions of pilgrims."
    },
    %{
      id: "beatification",
      year: "2020",
      label: "Beatified",
      title: "Blessed Carlo",
      text:
        "After the healing of a Brazilian boy with a congenital pancreatic malformation through Carlo's intercession, he is beatified in the Basilica of St. Francis at Assisi on October 10, 2020."
    },
    %{
      id: "canonization",
      year: "2025",
      label: "Canonized",
      title: "The first millennial saint",
      text:
        "Following the healing of a young Costa Rican woman gravely injured in Florence, Pope Leo XIV canonizes Carlo Acutis in St. Peter's Square on September 7, 2025, together with Pier Giorgio Frassati. He is the first saint to have grown up with the internet."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "St. Carlo Acutis")
      |> assign(
        meta_description:
          "St. Carlo Acutis, the first millennial saint: daily Mass, the daily Rosary, and a website cataloguing the Eucharistic miracles of the world. Canonized September 7, 2025, he is the patron of Lumen Viae."
      )
      |> assign(moments: @moments, selected_moment: "birth")

    {:ok, socket}
  end

  @impl true
  def handle_event("select-moment", %{"moment" => moment}, socket) do
    valid? = Enum.any?(@moments, &(&1.id == moment))
    {:noreply, if(valid?, do: assign(socket, :selected_moment, moment), else: socket)}
  end

  @doc """
  Returns the currently selected timeline moment.
  """
  def current_moment(moments, moment_id) do
    Enum.find(moments, &(&1.id == moment_id)) || hd(moments)
  end
end
