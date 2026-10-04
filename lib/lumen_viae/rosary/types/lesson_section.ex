defmodule LumenViae.Rosary.Types.LessonSection do
  @moduledoc """
  One part of a lesson, under its heading. `shows` says what it draws: `anatomy` (the `guided_rosary` section's anatomy), `steps` (the course's steps), `prayers` (the prayers named in `prayer_ids`, from the `prayers` section, with their `prayer_counts`), `categories` (the sets named in `categories`), `dwell` (the numbered `items`) or `week` (this week's mysteries, from the `schedule` section). A client should pass over a section whose `shows` it does not know.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :title, :string, description: "Its heading, or null where the lesson sets none."

    field :shows, :string,
      allow_nil?: false,
      description: "What it draws; see the type's description."

    field :prayer_ids, {:array, :string},
      constraints: [nil_items?: false],
      description:
        "For `prayers`: the prayers, in the order the lesson teaches them (the Hail Mary first)."

    field :categories, {:array, :string},
      constraints: [nil_items?: false],
      description: "For `categories`: the category slugs."

    field :items, {:array, Types.NumberedPoint},
      constraints: [nil_items?: false],
      description: "For `dwell`: the points, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :lesson_section
end
