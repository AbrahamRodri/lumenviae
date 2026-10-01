defmodule LumenViae.Rosary.Types.VerseGroup do
  @moduledoc """
  One mystery's verses, keyed as its announcement is, in bead order. The
  app reads `clips[n - 1]` as Hail Mary n. GraphQL has no map type, so the
  REST manifest's keyed map becomes a list of groups that carry their keys.
  """
  use Ash.TypedStruct

  typed_struct do
    field :key, :string, allow_nil?: false

    field :clips, {:array, LumenViae.Rosary.Types.VerseClip},
      allow_nil?: false,
      constraints: [nil_items?: false]
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :verse_group
end
