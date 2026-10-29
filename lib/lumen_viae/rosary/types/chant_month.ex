defmodule LumenViae.Rosary.Types.ChantMonth do
  @moduledoc """
  A month's traditional dedication and what the Chant Library sings for
  it (`ChantMonth` in the iOS app). February, the Holy Family's, has no
  chant of its own and is not listed.
  """
  use Ash.TypedStruct

  typed_struct do
    field :month, :integer, allow_nil?: false, description: "The month, 1 to 12."

    field :title, :string,
      allow_nil?: false,
      description: "Its dedication (`The Month of the Holy Rosary`)."

    field :chant_ids, {:array, :string},
      allow_nil?: false,
      description: "The chants sung for it, in order. May be empty."

    field :occasion_id, :string,
      description: "An occasion sung for it (`sung_rosary` in October), or null."

    field :feast_id, :string, description: "The month's own feast in `feasts`, or null."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_month
end
