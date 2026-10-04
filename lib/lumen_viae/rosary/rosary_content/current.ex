defmodule LumenViae.Rosary.RosaryContent.Current do
  @moduledoc """
  Answers a `LumenViae.Rosary.RosaryContent` read with the one document
  there is, stamped with its version and the moment it last changed.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent

  @impl true
  def prepare(query, _opts, _context) do
    %{version: version, updated_at: updated_at} = stamp()

    record = struct(RosaryContent, %{id: "current", version: version, updated_at: updated_at})

    Simple.set_data(query, [record])
  end

  @doc """
  The document's `version` and `updated_at`. Today it is the fixed content
  alone (`Content.version/1`, `Content.updated_at/0`). A section served
  from the database is folded in here: its rows into the version, so a
  curator's edit moves it, and its newest change into the date, taking
  the later of the two.
  """
  @spec stamp() :: %{version: String.t(), updated_at: DateTime.t()}
  def stamp do
    %{version: Content.version(), updated_at: Content.updated_at()}
  end
end
