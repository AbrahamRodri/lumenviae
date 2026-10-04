defmodule LumenViae.Rosary.Types.RosaryLearn do
  @moduledoc """
  The How to Pray course, as `GET /api/v2/rosary-content` serves it in its `learn` section: three lessons, then "Your First Rosary", with the steps, how often each prayer is said, Montfort's counsel and the questions beginners ask. The words are the iOS app's, from `priv/rosary_content/learn.json`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :intro, :string, allow_nil?: false, description: "The course's opening paragraph."

    field :lessons, {:array, Types.RosaryLesson},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The three lessons, in order."

    field :first_rosary, Types.FirstRosary,
      allow_nil?: false,
      description:
        "The course's last station: the Rosary prayed with a guide (the `guided_rosary` section)."

    field :steps, {:array, Types.RosaryStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "How to pray the Rosary, step by step, each with the prayers said at it. Lesson 1's \"The order\"."

    field :prayer_counts, {:array, Types.PrayerCount},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "How often each of the Rosary's eight prayers comes round in one Rosary of five decades, in the order lesson 2 teaches them."

    field :shelves, {:array, Types.ReadingShelf},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Montfort's counsel (`montfort_methods`) and the questions beginners ask (`rosary_questions`), each a shelf of short readings."

    field :scripture, Types.ScriptureNotes,
      allow_nil?: false,
      description: "The words that frame the mysteries in Scripture."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_learn
end
