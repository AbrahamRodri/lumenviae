defmodule LumenViae.Rosary.Types.LibraryShelf do
  @moduledoc """
  A shelf of library readings, in the order they are read.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The shelf's id. Stable forever."
    field :title, :string, allow_nil?: false, description: "Its name."
    field :subtitle, :string, allow_nil?: false, description: "One line under the name."

    field :margin_label, :string,
      allow_nil?: false,
      description: "Its name for a narrow margin, with a line break (`\\n`) where it reads best."

    field :icon, :string,
      allow_nil?: false,
      description: "The iOS app's glyph name for it (`ch-lily`), for reference."

    field :footnote, :string,
      description: "A closing line for a shelf that only samples a larger tradition, or null."

    field :readings, {:array, Types.LibraryReading},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its readings in order. A reading's place is shown as a Roman numeral."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :library_shelf
end
