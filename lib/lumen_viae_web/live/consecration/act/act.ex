defmodule LumenViaeWeb.Live.Consecration.Act do
  @moduledoc """
  `/consecration/act`: the end of the 33 days, the Act of Consecration
  made, as the app's `ConsecrationCompletionView`, on Consecration Day's
  warm gold-dark ground: the seal, CONSECRATED, "I am all yours" with its
  Latin, Totus tuus ego sum, the two lines of what was done, and the quiet
  way back to the Consecration. Consecration Day's Amen comes here.

  Beneath them, the Act's own words, to renew it each year as the page
  asks (the app prays them on Consecration Day's page just before, and
  links the book's chapter on them), and under a plan in this browser,
  Restart, which clears it. Anyone may open the page; nothing is kept.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Consecration.{Days, State}
  alias LumenViaeWeb.Live.Prayers.PrayerText
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Prayers.Prayer.Text

  @impl true
  def mount(_params, _session, socket) do
    doc = Days.load(socket.assigns.current_admin)
    phase = Days.phase_by_id(doc, "consecration_day")
    act = doc.prayers["act_of_consecration"]

    {:ok,
     socket
     |> PageMeta.put(Days.act_path(),
       title: "The Act of Consecration, Consecration to Mary",
       description:
         "I am all yours: the Act of Consecration to Jesus through Mary, made at the end of the 33 days, in St. Louis de Montfort's words.",
       image: PageMeta.named_image("glorious_coronation"),
       trail: [{"Consecration", Days.path()}, {"The Act of Consecration", Days.act_path()}]
     )
     |> assign(:doc, doc)
     |> assign(:phase, phase)
     |> assign(:act, act)
     |> assign(:stanzas, act && PrayerText.stanzas(act.english, nil, "english"))
     |> State.init()}
  end

  @impl true
  def handle_event("consecration_state", params, socket),
    do: {:noreply, State.put(socket, params, socket.assigns.doc.feasts)}

  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
