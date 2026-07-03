defmodule LumenViaeWeb.Live.Home.App.Index do
  @moduledoc """
  Landing page for the Lumen Viae iOS app.

  Marketing page showcasing the mobile app with sample screens,
  feature highlights, and download call-to-actions.
  """
  use LumenViaeWeb, :live_view

  @features [
    %{
      title: "Guided Audio Rosary",
      description:
        "Pray along with narrated meditations for every decade. Press play, close your eyes, and let the mysteries unfold."
    },
    %{
      title: "The Daily Mysteries",
      description:
        "The app knows the traditional schedule. Open it on a Tuesday and the Sorrowful Mysteries are waiting for you."
    },
    %{
      title: "Meditations of the Saints",
      description:
        "St. Louis de Montfort, St. Alphonsus Liguori, and the doctors of the Church accompany every mystery."
    },
    %{
      title: "Themed Perspectives",
      description:
        "Pray the same mysteries as a father, through the lens of humility, or in a season of suffering."
    },
    %{
      title: "Listen Anywhere",
      description:
        "Meditations stream instantly and continue in the background, on a commute, on a walk, or in the pew before Mass."
    },
    %{
      title: "Free of Distraction",
      description:
        "No feeds, no streaks, no noise. A quiet interface designed for recollection, in keeping with tradition."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Lumen Viae for iPhone")
     |> assign(:features, @features)}
  end
end
