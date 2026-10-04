defmodule LumenViae.Rosary.Types.RosaryMystery do
  @moduledoc """
  One mystery as the `mysteries` section of `GET /api/v2/rosary-content`
  serves it: the row in the `mysteries` table, keyed as the app keys it,
  with the announcement the spoken Rosary makes of it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :key, :string,
      allow_nil?: false,
      description:
        "`<category>_<order>`: `joyful_1`. The key the verses, the announcement and every other section use. Never the server's id."

    field :category, :string, allow_nil?: false, description: "The category's slug."

    field :order, :integer,
      allow_nil?: false,
      description: "Its place in the category, from 1."

    field :name, :string, allow_nil?: false, description: "The mystery's name."
    field :description, :string, description: "A sentence on what happens in it."
    field :scripture_reference, :string, description: "Where the Gospel tells it."

    field :fruit, :string, description: "The grace it is prayed for: `Humility`."

    field :key_verse, :string,
      description:
        "One verse to carry into the decade, in the Douay-Rheims, without its citation. Another rendering than the Scriptural Rosary's verses, and served as written."

    field :key_verse_reference, :string, description: "The key verse's citation."

    field :announcement, :string,
      allow_nil?: false,
      description:
        "What the spoken Rosary says before the decade, exactly as recorded: `The First Joyful Mystery: The Annunciation`."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_mystery
end
