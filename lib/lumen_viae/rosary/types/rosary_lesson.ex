defmodule LumenViae.Rosary.Types.RosaryLesson do
  @moduledoc """
  One lesson of the How to Pray course.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string, allow_nil?: false, description: "`beads`, `prayers` or `mysteries`."
    field :number, :integer, allow_nil?: false, description: "Its place in the course, from 1."
    field :title, :string, allow_nil?: false, description: "Its name."
    field :summary, :string, allow_nil?: false, description: "One line saying what it teaches."

    field :paragraphs, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its opening prose, a paragraph to an item. The first may open on a versal."

    field :sections, {:array, Types.LessonSection},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "What follows the prose, in order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_lesson
end
