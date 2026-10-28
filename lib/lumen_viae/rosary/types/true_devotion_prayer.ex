defmodule LumenViae.Rosary.Types.TrueDevotionPrayer do
  @moduledoc """
  One of the ejaculatory prayers on True Devotion's summary page, in
  English and Latin.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false, description: "Its title (`Totus Tuus`)."

    field :english, :string,
      allow_nil?: false,
      description: "The English, in the Prayer Book's grammar."

    field :latin, :string,
      allow_nil?: false,
      description: "The Latin, pairing with the English line for line."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :true_devotion_prayer
end
