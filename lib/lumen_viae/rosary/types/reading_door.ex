defmodule LumenViae.Rosary.Types.ReadingDoor do
  @moduledoc """
  Where a reading leads, as a neutral target a client maps to its own screen. `kind` and `target`: `act` (`todays_rosary`: begin today's Rosary; in the library documents also `mass` and `consecration`), `reading` (a reading on this document's shelves), `library` (`montfort`, `cana`: a reading the iOS app holds that this document does not serve; a client that has no such reading leaves the door out), `prayer` (an id in the `prayers` section; in the library documents, a Prayer Book prayer), `mysteries` (the library documents: a category slug) or `page` (`mysteries_in_scripture`; in the library documents also `marian_library`, `carlo_acutis`, `true_devotion`, `true_devotion_book` and `how_to_pray`). docs/JSON_API.md has each document's vocabulary. A client should pass over a door it cannot open.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description: "`act`, `reading`, `library`, `prayer`, `mysteries` or `page`."

    field :target, :string,
      allow_nil?: false,
      description: "What it opens; see the type's description."

    field :title, :string,
      description: "The door's name, or null for an `act`, which the client names."

    field :note, :string, allow_nil?: false, description: "The line under it."

    field :icon, :string,
      description: "The iOS app's glyph name for it, for reference; null for an `act`."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reading_door
end
