defmodule LumenViae.Rosary.Types.PrayerOrderVariant do
  @moduledoc """
  What an order of prayer becomes in a season: another name and other
  prayers. Only the Angelus has one, Queen of Heaven in Eastertide.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false, description: "Its name in the season."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its prayers in the season, each one of the document's prayers."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_order_variant
end
