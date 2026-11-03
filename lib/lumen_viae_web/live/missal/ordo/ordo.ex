defmodule LumenViaeWeb.Live.Missal.Ordo do
  @moduledoc """
  `/missal/order-of-mass`: the Order of Mass, the iOS app's
  `OrdoMissaeView`: the fixed parts of every traditional Latin Mass,
  Asperges to the Prayers after Mass, from Missale Meum, read in Latin,
  English or Both (`?lang=`, as the day's page; English never written),
  under EVERY MASS and the page's own line, with the credit at its foot.
  The app reaches it from the foot of a day's Mass, and so does the site.
  Its parts stand in a rail beside the text from 1024px and a jump list
  above it on a phone, as the day's do; the app has neither.

  The text is `LumenViae.Office.fetch_order_of_mass/0`, fetched by the
  server and cached there, after the page is shown; when it cannot be
  reached the page says so with a Try again, which asks again only after
  a failure.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.PartsRail
  alias LumenViaeWeb.Live.Missal.{Days, MissalText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Missal.Section

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.put("/missal/order-of-mass",
       title: "The Order of Mass",
       description:
         "The Order of Mass (Ordo Missae): the prayers said at every traditional Latin Mass, from the Asperges to the Last Gospel, in Latin and English.",
       image: PageMeta.named_image("topic_holy_mass"),
       trail: [{"The Mass", "/missal"}, {"The Order of Mass", "/missal/order-of-mass"}]
     )
     |> assign(ordo: nil, sections: [], languages: MissalText.languages())
     |> load()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:language, MissalText.language(params["lang"]))
     |> assign_sections()}
  end

  @impl true
  def handle_event("retry", _params, %{assigns: %{state: :failed}} = socket),
    do: {:noreply, load(socket)}

  def handle_event("retry", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:ordo, {:ok, {:ok, ordo}}, socket),
    do: {:noreply, socket |> assign(ordo: ordo, state: :ready) |> assign_sections()}

  def handle_async(:ordo, _failed, socket), do: {:noreply, assign(socket, :state, :failed)}

  defp load(socket) do
    socket = assign(socket, :state, :loading)

    if connected?(socket),
      do: start_async(socket, :ordo, &Office.fetch_order_of_mass/0),
      else: socket
  end

  defp assign_sections(%{assigns: %{ordo: ordo, language: language}} = socket)
       when is_list(ordo),
       do: assign(socket, :sections, MissalText.ordo_sections(ordo, language))

  defp assign_sections(socket), do: socket
end
