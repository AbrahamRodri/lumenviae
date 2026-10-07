defmodule LumenViaeWeb.Live.PrivacyPolicy.Index do
  @moduledoc """
  Privacy policy page for the Lumen Viae iOS and Android apps and the
  website.

  Keep it in step with the iOS app's own policy (`PrivacyPolicySheet`), its
  privacy manifest (`PrivacyInfo.xcprivacy`), the Android app's Google Play
  data safety answers and docs/COMPLETION_ANALYTICS.md.
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Privacy Policy")
     |> assign(
       :meta_description,
       "How Lumen Viae handles your information: what is collected, what is not, and how it is used."
     )}
  end
end
