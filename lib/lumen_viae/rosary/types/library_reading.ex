defmodule LumenViae.Rosary.Types.LibraryReading do
  @moduledoc """
  One short reading on a library shelf (the Marian Library, St. Carlo's
  life and devotions): `Types.Reading` with the painting it is hung in,
  the feast it is kept on and named parts after its prose.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The reading's id, unique across the app's shelves: a door of kind `reading` names it. Stable forever."

    field :title, :string, allow_nil?: false, description: "Its title."

    field :detail, :string,
      allow_nil?: false,
      description: "One line under the title: the date, council, place or witness."

    field :paragraphs, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its prose, a paragraph to an item."

    field :quote, Types.ReadingQuote, description: "A saying set apart, or null."

    field :painting, :string,
      description: "The painting it is hung in, by the apps' painting name, or null."

    field :feast, Types.LibraryFeast, description: "The feast it is kept on, or null."

    field :doors, {:array, Types.ReadingDoor},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Where the reading leads, in order; often empty."

    field :parts, {:array, Types.ReadingPart},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Named parts after the prose, each under its heading; often empty."

    field :tables, {:array, Types.ReadingTable},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Two-column tables after the prose; often empty."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :library_reading
end
