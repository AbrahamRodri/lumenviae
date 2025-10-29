defmodule LumenViaeWeb.Live.Home.Feedback.Index do
  @moduledoc """
  Simple LiveView for directing visitors to share feedback, issues, or feature requests.
  """
  use LumenViaeWeb, :live_view

  @contact_email "rodriguez.abrahamdev@gmail.com"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Share Feedback")
     |> assign(contact_email: @contact_email)
     |> assign(issue_mailto: build_mailto("Lumen Viae Issue Report"))
     |> assign(feature_mailto: build_mailto("Lumen Viae Feature Request"))}
  end

  defp build_mailto(subject) do
    "mailto:#{@contact_email}?subject=" <> URI.encode_www_form(subject)
  end
end
