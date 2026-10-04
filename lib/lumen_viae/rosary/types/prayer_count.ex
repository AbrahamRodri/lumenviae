defmodule LumenViae.Rosary.Types.PrayerCount do
  @moduledoc """
  How often one prayer comes round in a Rosary of five decades.
  """
  use Ash.TypedStruct

  typed_struct do
    field :prayer_id, :string, allow_nil?: false, description: "An id in the `prayers` section."

    field :count, :string,
      allow_nil?: false,
      description: "In words: \"Six times — once on each large bead\"."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_count
end
