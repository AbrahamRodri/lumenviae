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

    field :ai_translated, :boolean,
      description:
        "`true` when this quote's text in the asked-for language is the team's own AI translation, not a published text: show the app's AI notice. Present only then, and only with a `lang` other than English; otherwise absent."

    field :credit_in_credits_only, :boolean,
      description:
        "`true` on a quote whose author and source are not shown under it: credit it only in the app's sources and credits. Present only then, in every language; otherwise absent, and the credit shows under the quote as always."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_quote
end
