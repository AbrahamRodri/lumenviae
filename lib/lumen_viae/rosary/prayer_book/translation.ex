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

    field :ai_translated, :boolean,
      description:
        "`true` when part of the text is the team's own AI translation, not a published text: show the app's AI notice under it. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :book_prayer_translation
end
