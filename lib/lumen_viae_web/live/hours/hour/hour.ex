defmodule LumenViaeWeb.Live.Hours.Hour do
  @moduledoc """
  `/hours/:date/:hour`: one canonical hour read in full, as the iOS app's
  reader opens it (`OfficeHourView`, `OfficeSectionsView`): the hour's
  painting at the head with its name, the day stated once (the date with
  the day's class in plain words, then the feast), the parts of the hour
  to jump between, the text, and at its foot the scribe's close, the hours
  either side and the Divinum Officium credit, linked to the engine's own
  page for the hour.

  The language rides in the link as `?lang=latin` or `?lang=both`;
  English, the app's default, is never written. In Both the Latin leads
  and the English pairs with it line by line, as the Office is printed:
  side by side from 768px, the English beneath each Latin line on a phone
  (`OfficeText`). The app keeps the parts behind a "..." sheet and a
  sideways rail; here they are a rail beside the text on a wide screen,
  lit as the reader passes them (the `OfficeRail` hook), and a jump list
  above it on a phone.

  The text is `LumenViae.Office.fetch_hour/3` in English (which carries
  the Latin beside it), fetched after the page is shown (`start_async`)
  through the Office's cache; a failure says so with a Try again. A date
  or an hour the Office does not serve is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Office
  alias LumenViaeWeb.Live.Hours.{CanonicalHours, DayRank, OfficeText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting
  import LumenViaeWeb.Live.Hours.Hour.Section

  @impl true
  def mount(%{"date" => date_param, "hour" => slug}, _session, socket) do
    date =
      case CanonicalHours.parse_date(date_param) do
        {:ok, date} -> date
        :error -> raise LumenViaeWeb.NotFoundError, message: "no office for #{date_param}"
      end

    hour =
      CanonicalHours.fetch(slug) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown hour: #{slug}"

    title = "#{hour.plain} (#{hour.label}), #{CanonicalHours.long_date(date)}"

    {:ok,
     socket
     |> PageMeta.put(CanonicalHours.hour_path(date, slug),
       title: title,
       description:
         "#{hour.label} of the traditional Roman Breviary for #{CanonicalHours.long_date(date)}, in Latin and English.",
       trail: [
         {"Hours of Prayer", "/hours"},
         {CanonicalHours.long_date(date), CanonicalHours.day_path(date)},
         {hour.plain, CanonicalHours.hour_path(date, slug)}
       ]
     )
     |> assign(:date, date)
     |> assign(:hour, hour)
     |> assign(:previous, CanonicalHours.previous(hour))
     |> assign(:next, CanonicalHours.next(hour))
     |> assign(:languages, OfficeText.languages())
     |> assign(:credit, CanonicalHours.credit())
     |> assign(:office, nil)
     |> assign(:sections, [])
     |> load()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:language, OfficeText.language(params["lang"]))
     |> assign_sections()}
  end

  @impl true
  def handle_event("retry", _params, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_async(:office, {:ok, {:ok, office}}, socket) do
    {:noreply, socket |> assign(office: office, state: :ready) |> assign_sections()}
  end

  def handle_async(:office, _failed, socket), do: {:noreply, assign(socket, :state, :failed)}

  defp load(socket) do
    %{date: date, hour: hour} = socket.assigns
    date = Date.to_iso8601(date)
    socket = assign(socket, :state, :loading)

    if connected?(socket) do
      socket
      |> cancel_async(:office)
      |> start_async(:office, fn -> Office.fetch_hour(date, hour.slug) end)
    else
      socket
    end
  end

  defp assign_sections(%{assigns: %{office: nil}} = socket), do: socket

  defp assign_sections(%{assigns: %{office: office, language: language}} = socket),
    do: assign(socket, :sections, OfficeText.sections(office.sections, language))

  defp assign_sections(socket), do: socket

  @doc false
  def language_path(date, slug, language), do: CanonicalHours.hour_path(date, slug, language)

  # "Thursday, 27 August 2026 · Lesser Feast", the class once the hour has come.
  defp day_line(date, nil), do: CanonicalHours.long_date(date)

  defp day_line(date, office) do
    case DayRank.plain_for(office) do
      nil -> CanonicalHours.long_date(date)
      class -> "#{CanonicalHours.long_date(date)} · #{class}"
    end
  end
end
