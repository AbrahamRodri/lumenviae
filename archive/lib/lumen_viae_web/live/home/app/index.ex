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
        "St. Alphonsus Liguori, Blessed Anne Catherine Emmerich, St. John Chrysostom, and the doctors of the Church accompany every mystery."
    },
    %{
      title: "Two Ways of Meditating",
      description:
        "Enter the scene with the contemplatives, or reason on its meaning with the classical considerations. The same mystery, two paths in."
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
     |> assign(
       :meta_description,
       "Lumen Viae for iPhone: guided audio meditations on the mysteries of the Holy Rosary from the saints and doctors of the Church. Free, no account, no distractions."
     )
     |> assign(:features, @features)}
  end
end
