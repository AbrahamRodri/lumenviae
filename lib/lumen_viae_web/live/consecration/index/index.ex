defmodule LumenViaeWeb.Live.Consecration.Index do
  @moduledoc """
  `/consecration`: the 33-day Consecration to Jesus through Mary, as the
  app's Consecration tab opens it (`ConsecrationTabView`). With no plan in
  this browser it is the introduction (`ConsecrationOnboardingView`),
  four pages and then the feast chooser (`ConsecrationDateSelectionView`);
  `?step=devotion`, `day`, `journey` or `choose` names the page, the
  welcome never written, and a visitor who has reached the chooser before
  opens on it, as the app's returning reader does. A plan whose Day 1 is
  still ahead shows the waiting page (`ConsecrationScheduledView`); a plan
  under way goes on to today's day, `/consecration/days/:n`; and a
  finished one offers the feasts again under a note that it was made.

  The plan is the browser's alone (`LumenViaeWeb.Live.Consecration.Plan`,
  the `ConsecrationPlan` hook), so until the hook speaks the page stands
  as a quiet, still frame of the introduction: a crawler, or a browser
  without JavaScript, reads the welcome.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Consecration.{Days, Plan, State}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Consecration.Parts
  import LumenViaeWeb.Live.Consecration.Index.Intro
  import LumenViaeWeb.Live.Consecration.Index.Chooser
  import LumenViaeWeb.Live.Consecration.Index.Scheduled

  @steps ~w(welcome devotion day journey choose)

  @impl true
  def mount(_params, _session, socket) do
    doc = Days.load(socket.assigns.current_admin)

    {:ok,
     socket
     |> PageMeta.put(Days.path(),
       title: "Consecration to Mary",
       description:
         "A 33-day preparation to give yourself to Jesus through Mary, as St. Louis de Montfort taught: each day's prayers and readings, ending on a feast of Mary.",
       image: PageMeta.named_image("glorious_coronation"),
       trail: [{"Consecration", Days.path()}]
     )
     |> assign(:doc, doc)
     |> assign(:steps, @steps)
     |> assign(:selected_id, nil)
     |> assign(:more?, false)
     |> assign(:any?, false)
     |> assign(:any_day, 1)
     |> State.init()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:step_param, if(params["step"] in @steps, do: params["step"]))
     |> assign_page()}
  end

  @impl true
  def handle_event("consecration_state", params, socket) do
    socket = State.put(socket, params, socket.assigns.doc.feasts)

    case Plan.status(socket.assigns.plan, socket.assigns.today) do
      {:day, n} ->
        {:noreply, push_navigate(socket, to: Days.day_path(n), replace: true)}

      _other ->
        {:noreply, assign_page(socket)}
    end
  end

  def handle_event("select_feast", %{"id" => id}, socket) when is_binary(id),
    do: {:noreply, assign(socket, :selected_id, id) |> assign_page()}

  def handle_event("more_feasts", _params, socket),
    do: {:noreply, assign(socket, :more?, true) |> assign_page()}

  def handle_event("any_start", _params, socket),
    do: {:noreply, assign(socket, :any?, !socket.assigns.any?) |> assign_page()}

  def handle_event("any_day", %{"day" => day}, socket),
    do: {:noreply, assign(socket, :any_day, Plan.any_day(day)) |> assign_page()}

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp assign_page(socket) do
    %{doc: doc, plan: plan, today: today} = socket.assigns
    status = Plan.status(plan, today)

    step =
      cond do
        socket.assigns.step_param -> socket.assigns.step_param
        socket.assigns.intro_seen? -> "choose"
        true -> "welcome"
      end

    socket =
      if step == "choose" and connected?(socket),
        do: push_event(socket, "consecration:intro-seen", %{}),
        else: socket

    preparations = Plan.preparations(doc.feasts, today)

    selected =
      Enum.find(preparations, &(&1.feast.id == socket.assigns.selected_id)) ||
        List.first(preparations)

    socket
    |> assign(:status, status)
    |> assign(:step, step)
    |> assign(:preparations, preparations)
    |> assign(:selected, selected)
    |> assign(:any_phase, Days.phase_of(doc, socket.assigns.any_day))
  end

  @doc "An introduction page's path: the welcome is `/consecration`."
  def step_path("welcome"), do: Days.path()
  def step_path(step), do: Days.path() <> "?step=" <> step

  @doc "The page before `step` in the introduction, or nil on the welcome."
  def previous_step(step) do
    case Enum.find_index(@steps, &(&1 == step)) do
      i when is_integer(i) and i > 0 -> Enum.at(@steps, i - 1)
      _other -> nil
    end
  end
end
