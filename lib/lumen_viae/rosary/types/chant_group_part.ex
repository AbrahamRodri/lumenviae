defmodule LumenViae.Rosary.Types.ChantGroupPart do
  @moduledoc """
  A part of a chant group: a Mass of the Ordinary, a season, or the whole
  group when it has no parts of its own.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, description: "The part's heading (`Advent`), or null."
    field :note, :string, description: "When it is sung, or null."

    field :chant_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its chants in order, each one of the document's chants."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_group_part
end
