defmodule LumenViae.Rosary.Types.ChantFeast do
  @moduledoc """
  A day the Chant Library sings a chant for (`ChantFeast` in the iOS
  app): a feast, or one of Advent's O antiphon days, with the rule that
  finds its date in a year and the chant it names.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "Stable (`holy_name`); a month names it."
    field :name, :string, allow_nil?: false, description: "Its name (`The Holy Name of Jesus`)."

    field :rule, Types.ChantFeastRule,
      allow_nil?: false,
      description: "How its date is found in a given year."

    field :chant_id, :string, allow_nil?: false, description: "The chant sung for it."

    field :painting, :string,
      allow_nil?: false,
      description: "The painting it is shown in, by the apps' painting name."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_feast
end
