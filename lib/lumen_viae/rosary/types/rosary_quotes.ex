defmodule LumenViae.Rosary.Types.RosaryQuotes do
  @moduledoc """
  The `quotes` section of `GET /api/v2/rosary-content`: the daily quotations and how one is chosen. See docs/JSON_API.md, "The content document".
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :rotation, Types.QuoteRotation,
      allow_nil?: false,
      description: "How a quotation is chosen for a day."

    field :items, {:array, Types.RosaryQuote},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The quotations, in the order the rotation counts them. A client should keep to this order: the rotation indexes into it."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_quotes
end
