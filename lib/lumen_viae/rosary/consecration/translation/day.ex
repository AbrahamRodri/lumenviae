defmodule LumenViae.Rosary.Consecration.Translation.Day do
  @moduledoc "One Consecration day's words in another language. See `LumenViae.Rosary.Consecration.Translation`."
  use Ash.TypedStruct

  alias LumenViae.Rosary.Consecration.Translation

  typed_struct do
    field :number, :integer, allow_nil?: false, description: "The day, the same as in `days`."
    field :title, :string, allow_nil?: false, description: "Its theme in this language."

    field :journal_prompt, :string,
      allow_nil?: false,
      description: "Its journal question in this language."

    field :ai_translated, :boolean,
      description:
        "`true` when the title and journal question are the team's own AI translation: show the app's AI notice. Absent otherwise. Each reading carries its own mark."

    field :readings, {:array, Translation.Reading},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The day's readings that have this language, by `order`. A reading not listed has none: show its English."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_day_translation
end
