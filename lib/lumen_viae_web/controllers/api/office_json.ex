defmodule LumenViaeWeb.API.OfficeJSON do
  @moduledoc """
  Renders the Divine Office endpoints. Text arrives verbatim from the
  Divinum Officium engine - Latin on one side, the requested translation
  on the other - and every response names its source, because the texts
  are that project's work, not ours.
  """

  def versions(%{vocabulary: vocabulary}) do
    %{
      data: %{
        versions: Enum.map(vocabulary.versions, &slug_and_label/1),
        hours: Enum.map(vocabulary.hours, &slug_and_label/1),
        languages: Enum.map(vocabulary.languages, &slug_and_label/1),
        defaults: vocabulary.defaults
      }
    }
  end

  def calendar(%{calendar: calendar}) do
    %{
      data: %{
        year: calendar.year,
        month: calendar.month,
        version: calendar.version,
        days: Enum.map(calendar.days, &day_data/1)
      }
    }
  end

  def day(%{day: day}) do
    %{data: Map.put(day_data(day), :version, day.version)}
  end

  def hour(%{hour: hour}) do
    %{
      data: %{
        date: hour.date,
        hour: hour.hour,
        version: hour.version,
        language: hour.language,
        celebration: hour.celebration,
        tempora: hour.tempora,
        sections: Enum.map(hour.sections, &section_data/1),
        source: source(hour.source_url)
      }
    }
  end

  def day_data(day) do
    %{
      date: day.date,
      celebration: day.celebration,
      detail: day.detail,
      note: day.note,
      letter: day.letter
    }
  end

  defp section_data(section) do
    %{
      latin: cell_data(section.latin),
      vernacular: cell_data(section.vernacular)
    }
  end

  # A Latin-only office has no second column.
  defp cell_data(nil), do: nil

  defp cell_data(cell) do
    %{title: cell.title, note: cell.note, lines: cell.lines}
  end

  defp slug_and_label(entry) do
    %{slug: entry.slug, label: entry.label}
  end

  defp source(url) do
    %{name: "The Divinum Officium Project", url: url}
  end
end
