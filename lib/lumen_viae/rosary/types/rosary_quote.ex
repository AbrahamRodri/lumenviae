defmodule LumenViae.Rosary.Types.RosaryQuote do
  @moduledoc """
  A daily quotation: a saint, a pope or Our Lady on the Rosary.
  """
  use Ash.TypedStruct

  typed_struct do
    field :text, :string,
      allow_nil?: false,
      description: "The words."

    field :author, :string,
      allow_nil?: false,
      description:
        "Who is quoted, named as the Church now names them (`St. Pius X`, `Bl. Pius IX`)."

    field :source, :string,
      description:
        "The work or occasion, only where it can be cited with confidence. Null where the attribution is traditional rather than documented."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_quote
end
