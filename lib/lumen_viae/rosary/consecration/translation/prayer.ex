defmodule LumenViae.Rosary.Consecration.Translation.Prayer do
  @moduledoc "One Consecration prayer in another language. See `LumenViae.Rosary.Consecration.Translation`."
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
  def graphql_type(_), do: :consecration_prayer_translation
end
