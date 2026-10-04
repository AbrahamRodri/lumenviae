defmodule LumenViae.Rosary.Types.ReadingShelf do
  @moduledoc """
  A shelf of short readings.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The shelf's id."
    field :title, :string, allow_nil?: false, description: "Its name."
    field :subtitle, :string, allow_nil?: false, description: "One line under the name."

    field :margin_label, :string,
      allow_nil?: false,
      description: "The short label the app sets in the margin; a newline marks where it breaks."

    field :icon, :string,
      allow_nil?: false,
      description: "The iOS app's glyph name, for reference."

    field :readings, {:array, Types.Reading},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its readings, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_shelf
end
