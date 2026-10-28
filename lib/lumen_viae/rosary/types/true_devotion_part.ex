defmodule LumenViae.Rosary.Types.TrueDevotionPart do
  @moduledoc """
  One of the two parts True Devotion is divided into. The Introduction
  belongs to neither.
  """
  use Ash.TypedStruct

  typed_struct do
    field :number, :integer,
      allow_nil?: false,
      description: "The part, 1 or 2, as a chapter's `part` names it."

    field :title, :string,
      allow_nil?: false,
      description: "Its heading (`Part I — On Devotion to Our Lady in General`)."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :true_devotion_part
end
