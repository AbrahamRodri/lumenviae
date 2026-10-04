defmodule LumenViae.Rosary.RosaryContent.Current do
  @moduledoc """
  Answers a `LumenViae.Rosary.RosaryContent` read with the one document
  there is, stamped with its version and the moment it last changed.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent
  alias LumenViae.Rosary.RosaryContent.Schedule

  @impl true
  def prepare(query, _opts, _context) do
    %{version: version, updated_at: updated_at} = stamp()

    record = struct(RosaryContent, %{id: "current", version: version, updated_at: updated_at})

    Simple.set_data(query, [record])
  end

  @doc """
  The document's `version` and `updated_at`: the fixed content
  (`Content.version/1`, `Content.updated_at/0`) with every section served
  from code or the database folded in. A section from the database folds
  its rows into the version, so a curator's edit moves it, and its newest
  change into the date, taking the latest.

  The `schedule` section is computed from code for the current UTC year
  (`Schedule.section/1`): its served value joins the version, and its date
  (`Schedule.updated_at/1`) the dates, so the version moves when the year
  turns and its seasons move on.
  """
  @spec stamp(integer) :: %{version: String.t(), updated_at: DateTime.t()}
  def stamp(year \\ Schedule.current_year()) do
    served = Map.put(Content.document(), "schedule", Schedule.section(year))

    %{
      version: Content.version(served),
      updated_at: Enum.max([Content.updated_at(), Schedule.updated_at(year)], DateTime)
    }
  end
end
