defmodule LumenViae.Office.Versions do
  @moduledoc """
  The vocabulary of the Divine Office domain: which rubrical versions,
  canonical hours and translation languages the API serves, and how each
  maps onto the names the Divinum Officium engine expects.

  Slugs are what clients send and what responses echo back; the `do_*`
  values are what goes on the wire to the engine and never leave the
  server. The lists live here and nowhere else, the same way the mystery
  category vocabulary lives in `LumenViae.Rosary.Categories`.
  """

  @versions [
    %{slug: "tridentine-1570", do_version: "Tridentine - 1570", label: "Tridentine (1570)"},
    %{slug: "tridentine-1888", do_version: "Tridentine - 1888", label: "Tridentine (1888)"},
    %{slug: "tridentine-1906", do_version: "Tridentine - 1906", label: "Tridentine (1906)"},
    %{
      slug: "divino-afflatu-1939",
      do_version: "Divino Afflatu - 1939",
      label: "Divino Afflatu (1939)"
    },
    %{
      slug: "divino-afflatu-1954",
      do_version: "Divino Afflatu - 1954",
      label: "Divino Afflatu (1954)"
    },
    %{slug: "reduced-1955", do_version: "Reduced - 1955", label: "Reduced (1955)"},
    %{
      slug: "rubrics-1960",
      do_version: "Rubrics 1960 - 1960",
      label: "Rubrics 1960 (1962 books)"
    },
    %{
      slug: "rubrics-1960-usa-2020",
      do_version: "Rubrics 1960 - 2020 USA",
      label: "Rubrics 1960, USA (2020)"
    },
    %{slug: "monastic-1617", do_version: "Monastic Tridentinum 1617", label: "Monastic (1617)"},
    %{slug: "monastic-1930", do_version: "Monastic Divino 1930", label: "Monastic (1930)"},
    %{slug: "monastic-1963", do_version: "Monastic - 1963", label: "Monastic (1963)"},
    %{
      slug: "ordo-praedicatorum-1962",
      do_version: "Ordo Praedicatorum - 1962",
      label: "Dominican (1962)"
    }
  ]

  @default_version "rubrics-1960"

  @hours [
    %{slug: "matutinum", do_hour: "Matutinum", label: "Matins"},
    %{slug: "laudes", do_hour: "Laudes", label: "Lauds"},
    %{slug: "prima", do_hour: "Prima", label: "Prime"},
    %{slug: "tertia", do_hour: "Tertia", label: "Terce"},
    %{slug: "sexta", do_hour: "Sexta", label: "Sext"},
    %{slug: "nona", do_hour: "Nona", label: "None"},
    %{slug: "vesperae", do_hour: "Vesperae", label: "Vespers"},
    %{slug: "completorium", do_hour: "Completorium", label: "Compline"}
  ]

  # The engine's own spellings, downcased. "Latin-gabc" (chant notation) is
  # deliberately absent: it changes the markup the parser relies on.
  @languages [
    %{slug: "latin", do_language: "Latin", label: "Latin"},
    %{slug: "english", do_language: "English", label: "English"},
    %{slug: "bohemice", do_language: "Bohemice", label: "Czech"},
    %{slug: "cesky-schaller", do_language: "Cesky-Schaller", label: "Czech (Schaller)"},
    %{slug: "dansk", do_language: "Dansk", label: "Danish"},
    %{slug: "deutsch", do_language: "Deutsch", label: "German"},
    %{slug: "espanol", do_language: "Espanol", label: "Spanish"},
    %{slug: "francais", do_language: "Francais", label: "French"},
    %{slug: "italiano", do_language: "Italiano", label: "Italian"},
    %{slug: "magyar", do_language: "Magyar", label: "Hungarian"},
    %{slug: "magyar-kaldi", do_language: "Magyar-Kaldi", label: "Hungarian (Kaldi)"},
    %{slug: "nederlands", do_language: "Nederlands", label: "Dutch"},
    %{slug: "polski", do_language: "Polski", label: "Polish"},
    %{slug: "polski-newer", do_language: "Polski-Newer", label: "Polish (newer)"},
    %{slug: "portugues", do_language: "Portugues", label: "Portuguese"},
    %{slug: "vietnamice", do_language: "Vietnamice", label: "Vietnamese"},
    %{slug: "hebrew", do_language: "Hebrew", label: "Hebrew"},
    %{slug: "latin-bea", do_language: "Latin-Bea", label: "Latin (Bea psalter)"}
  ]

  @default_language "english"

  def versions, do: @versions
  def hours, do: @hours
  def languages, do: @languages

  def default_version, do: @default_version
  def default_language, do: @default_language

  def fetch_version(slug), do: fetch_by_slug(@versions, slug)
  def fetch_hour(slug), do: fetch_by_slug(@hours, slug)
  def fetch_language(slug), do: fetch_by_slug(@languages, slug)

  def version_slugs, do: Enum.map(@versions, & &1.slug)
  def hour_slugs, do: Enum.map(@hours, & &1.slug)
  def language_slugs, do: Enum.map(@languages, & &1.slug)

  defp fetch_by_slug(entries, slug) when is_binary(slug) do
    case Enum.find(entries, &(&1.slug == slug)) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  defp fetch_by_slug(_entries, _slug), do: :error
end
