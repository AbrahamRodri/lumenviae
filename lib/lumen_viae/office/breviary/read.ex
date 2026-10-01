defmodule LumenViae.Office.Breviary.Read do
  @moduledoc """
  Runs the breviary's generic actions by calling the domain's fetch
  functions and shaping their answers into the Office's GraphQL types.

  The domain speaks the REST controller's dialect: raw string parameters
  in, `{:error, {:bad_request, message}}` and `{:error, :office_unavailable}`
  out. This module translates both directions, so the domain stays the one
  place that decides what a valid request is.
  """
  use Ash.Resource.Actions.Implementation

  alias LumenViae.Office
  alias LumenViae.Office.Errors
  alias LumenViae.Office.Types
  alias LumenViae.Office.Versions

  @impl true
  def run(input, opts, _context) do
    input.arguments
    |> fetch(opts[:kind])
    |> translate_error()
  end

  defp fetch(args, :hour) do
    with {:ok, hour} <-
           Office.fetch_hour(Date.to_iso8601(args.date), args.hour, params(args)) do
      {:ok, hour(hour)}
    end
  end

  # Sequential on purpose: each hour the cache does not hold is a request
  # to the upstream engine, and eight at once is not a load to put on a
  # volunteer project for one reader.
  defp fetch(args, :hours) do
    date = Date.to_iso8601(args.date)
    params = params(args)

    Versions.hour_slugs()
    |> Enum.reduce_while({:ok, []}, fn slug, {:ok, hours} ->
      case Office.fetch_hour(date, slug, params) do
        {:ok, hour} -> {:cont, {:ok, [hour(hour) | hours]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, hours} -> {:ok, Enum.reverse(hours)}
      error -> error
    end
  end

  defp fetch(args, :day) do
    with {:ok, day} <- Office.fetch_day(Date.to_iso8601(args.date), params(args)) do
      {:ok, day(day)}
    end
  end

  defp fetch(args, :calendar) do
    with {:ok, calendar} <- Office.fetch_calendar(args.year, args.month, params(args)) do
      {:ok,
       %Types.Calendar{
         year: calendar.year,
         month: calendar.month,
         version: calendar.version,
         days: Enum.map(calendar.days, &day/1)
       }}
    end
  end

  defp fetch(_args, :vocabulary) do
    vocabulary = Office.vocabulary()

    {:ok,
     %Types.Vocabulary{
       versions: Enum.map(vocabulary.versions, &choice/1),
       hours: Enum.map(vocabulary.hours, &choice/1),
       languages: Enum.map(vocabulary.languages, &choice/1),
       default_version: vocabulary.defaults.version,
       default_language: vocabulary.defaults.language
     }}
  end

  # Only the arguments the caller actually gave: the domain applies its
  # own defaults to anything missing.
  defp params(args) do
    args
    |> Map.take([:version, :language])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  defp hour(hour) do
    %Types.Hour{
      date: hour.date,
      hour: hour.hour,
      version: hour.version,
      language: hour.language,
      celebration: celebration(hour.celebration),
      tempora: hour.tempora,
      sections: Enum.map(hour.sections, &section/1),
      source: struct(Types.Source, Office.source(hour.source_url))
    }
  end

  defp day(day) do
    %Types.Day{
      date: day.date,
      celebration: celebration(day.celebration),
      detail: day.detail && struct(Types.Detail, day.detail),
      note: day.note,
      letter: day.letter
    }
  end

  defp section(section) do
    %Types.Section{latin: cell(section.latin), vernacular: cell(section.vernacular)}
  end

  defp cell(nil), do: nil
  defp cell(cell), do: %Types.Cell{title: cell.title, note: cell.note, lines: cell.lines}

  defp celebration(nil), do: nil
  defp celebration(celebration), do: struct(Types.Celebration, celebration)

  defp choice(entry), do: %Types.Choice{slug: entry.slug, label: entry.label}

  defp translate_error({:error, {:bad_request, message}}),
    do: {:error, Errors.BadRequest.exception(message: message)}

  defp translate_error({:error, :office_unavailable}),
    do: {:error, Errors.Unavailable.exception([])}

  # A date inside a month the engine knows, but missing from its calendar
  # page. The REST API answers 404 for it.
  defp translate_error({:error, :not_found}),
    do: {:error, Ash.Error.Query.NotFound.exception(resource: LumenViae.Office.Breviary)}

  defp translate_error(result), do: result
end
