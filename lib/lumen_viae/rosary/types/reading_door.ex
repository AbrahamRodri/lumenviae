defmodule LumenViae.Rosary.Types.ReadingDoor do
  @moduledoc """
  Where a reading leads, as a neutral target a client maps to its own screen. `kind` and `target`: `act` (`todays_rosary`: begin today's Rosary), `reading` (a reading id: one on this document's shelves, or a reading of the app's libraries this document does not hold yet, `montfort` and `cana`), `prayer` (an id in the `prayers` section) or `page` (`mysteries_in_scripture`). A client should pass over a door it cannot open.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string, allow_nil?: false, description: "`act`, `reading`, `prayer` or `page`."

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
