defmodule LumenViae.Rosary.Types.RosaryPrayer do
  @moduledoc """
  One of the twelve prayers of the Rosary and the Seven Sorrows chaplet, in
  English and Latin, as `GET /api/v2/rosary-content` serves it. See
  `LumenViae.Rosary.Content` for where the words live.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The app's prayer id (`hail_mary`), the key the spoken Rosary's recordings and steps use."

    field :group, :string,
      allow_nil?: false,
      description:
        "`rosary`: one of the Rosary's eight prayers. `chaplet`: the Seven Sorrows chaplet's own. `after`: an optional prayer after the Rosary. A client should keep a prayer whose group it does not know."

    field :title, Types.PrayerTitle, allow_nil?: false, description: "The prayer's name."

    field :text, Types.PrayerText,
      allow_nil?: false,
      description:
        "The words, as lines broken where they are shown. Both languages have the same number of lines, so they pair line for line. A line in square brackets is a rubric (`[Let us pray.]`)."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_prayer
end
