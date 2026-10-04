defmodule LumenViae.Rosary.Types.Reading do
  @moduledoc """
  One short reading.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The reading's id, unique across the app's shelves: a door of kind `reading` names it."

    field :title, :string, allow_nil?: false, description: "Its title."
    field :detail, :string, allow_nil?: false, description: "One line under the title."

    field :paragraphs, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its prose, a paragraph to an item."

    field :quote, Types.ReadingQuote, description: "A saying set apart, or null."

    field :tables, {:array, Types.ReadingTable},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Two-column tables, after the prose; often empty."

    field :doors, {:array, Types.ReadingDoor},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Where the reading leads, in order; often empty."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading
end
