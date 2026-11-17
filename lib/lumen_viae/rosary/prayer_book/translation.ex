defmodule LumenViae.Rosary.PrayerBook.Translation do
  @moduledoc """
  One Prayer Book prayer in the language a read asked for, as the
  `translations` section of `GET /api/v2/prayer-book?lang=es` serves it.
  See `LumenViae.Rosary.PrayerBook.Spanish`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The prayer's id, the same as in `prayers`."

    field :title, :string, allow_nil?: false, description: "Its title in this language."

    field :text, :string,
      allow_nil?: false,
      description:
        "Its words in this language, in the same PrayerText grammar as `english`. Its lines need not pair with the English or the Latin."

    field :origin, :string,
      description:
        "Where it comes from, in this language, standing in place of the prayer's `origin`. Absent where there is none yet: a client then shows no origin rather than the English one."

    field :foot_credit, :string,
      description:
        "The exact line to show at the foot in this language, in place of the prayer's `origin` and `origin_credit`: the whole `origin` where the English origin is a credit, else only the part naming the book, publisher or shrine this wording is taken from (\"Según el Compendio del Catecismo de la Iglesia Católica\"). Absent where the foot shows nothing: the origin is only a tradition and a century, or the team's own translation. Lists of sources keep `origin`."

    field :short_credit, :string,
      description:
        "This language's short credit to show under the title, as the prayer's own `short_credit`: present only where the prayer's English carries one. Absent otherwise. `foot_credit` is what shows at the foot."

    field :ai_translated, :boolean,
      description:
        "`true` when part of the text is the team's own AI translation, not a published text: show the app's AI notice under it. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :book_prayer_translation
end
