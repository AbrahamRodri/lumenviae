defmodule LumenViae.Rosary.Library.Current do
  @moduledoc """
  Answers a `LumenViae.Rosary.PrayerBook`, `LumenViae.Rosary.ChantLibrary`
  or `LumenViae.Rosary.Consecration` read with the one document there is, stamped with its version and the
  moment it last changed (`LumenViae.Rosary.Library.stamp/1`). `document`
  names which.
  """
  use Ash.Resource.Preparation

  alias Ash.DataLayer.Simple
  alias LumenViae.Rosary.Library

  @impl true
  def init(opts) do
    if opts[:document] in Library.documents(),
      do: {:ok, opts},
      else: {:error, "document must be one of #{inspect(Library.documents())}"}
  end

  @impl true
  def prepare(query, opts, _context) do
    stamp = Library.stamp(opts[:document])
    record = struct(query.resource, Map.put(stamp, :id, "current"))

    Simple.set_data(query, [record])
  end
end
