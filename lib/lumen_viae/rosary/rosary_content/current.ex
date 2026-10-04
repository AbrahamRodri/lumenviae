defmodule LumenViae.Rosary.RosaryContent.Current do
  @moduledoc """
  Answers a `LumenViae.Rosary.RosaryContent` read with the one document
  there is, stamped with its version and the moment it last changed.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent
  alias LumenViae.Rosary.RosaryContent.Categories
  alias LumenViae.Rosary.RosaryContent.Labels
  alias LumenViae.Rosary.RosaryContent.Mysteries
  alias LumenViae.Rosary.RosaryContent.Schedule
  alias LumenViae.Rosary.RosaryContent.Verses

  @impl true
  def prepare(query, _opts, context) do
    %{version: version, updated_at: updated_at} =
      stamp(Schedule.current_year(), Ash.Context.to_opts(context))

    record = struct(RosaryContent, %{id: "current", version: version, updated_at: updated_at})

    Simple.set_data(query, [record])
  end

  @doc """
  The document's `version` and `updated_at`: the fixed content
  (`Content.version/1`, `Content.updated_at/0`) with every section served
  from code or the database folded in. A section from code brings its
  served value and its own date; a section from the database brings its
  rows, so a curator's edit moves the version, and its newest change, so
  it moves the date. The date is the latest of them all.

  The `schedule` section is computed from code for the current UTC year
  (`Schedule.section/1`): its served value joins the version, and its date
  (`Schedule.updated_at/1`) the dates, so the version moves when the year
  turns and its seasons move on.

  The `labels` section is code too (`Labels.section/0`, dated in its
  module and pinned in its test).

  The `mysteries` section is the one read from the database (`opts` are
  the caller's, for that read); `categories` and `verses` are code, dated
  in their own modules.
  """
  @spec stamp(integer, keyword) :: %{version: String.t(), updated_at: DateTime.t()}
  def stamp(year \\ Schedule.current_year(), opts \\ []) do
    mysteries = Mysteries.rows(opts)

    sections = [
      {"content", Content.document(), Content.updated_at()},
      {"schedule", Schedule.section(year), Schedule.updated_at(year)},
      {"categories", Categories.all(), Categories.updated_at()},
      {"labels", Labels.section(), Labels.updated_at()},
      {"verses", Verses.groups(), Verses.updated_at()},
      {"mysteries", Enum.map(mysteries, &elem(&1, 0)),
       mysteries |> Enum.map(&elem(&1, 1)) |> Enum.max(DateTime, fn -> Content.updated_at() end)}
    ]

    version =
      sections
      |> Map.new(fn {name, value, _updated_at} -> {name, plain(value)} end)
      |> Content.version()

    updated_at =
      sections |> Enum.map(fn {_name, _value, at} -> at end) |> Enum.max(DateTime)

    %{version: version, updated_at: updated_at}
  end

  @doc """
  Every section `stamp/2` folds in: each content file's sections
  (`Content.document/0`) and the five computed beside them. A section the
  resource serves must be one of these, or a change to it would not move
  the version; `rosary_content_sections_test.exs` holds the two together.
  """
  @spec folded_sections() :: [String.t()]
  def folded_sections do
    Map.keys(Content.document()) ++ ~w(schedule categories labels verses mysteries)
  end

  # Typed structs as plain maps, so Content.version/1 can order their keys.
  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  defp plain(struct)
       when is_struct(struct) and not is_struct(struct, DateTime) and
              not is_struct(struct, Date) do
    struct |> Map.from_struct() |> Map.new(fn {key, value} -> {key, plain(value)} end)
  end

  defp plain(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {key, value} -> {key, plain(value)} end)

  defp plain(value), do: value
end
