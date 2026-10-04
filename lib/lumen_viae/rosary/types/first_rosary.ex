defmodule LumenViae.Rosary.Types.FirstRosary do
  @moduledoc """
  "Your First Rosary": the course's last station, and the welcome before the guided Rosary begins.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false, description: "Its name."
    field :summary, :string, allow_nil?: false, description: "One line saying what it is."

    field :welcome, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The welcome's first paragraphs."

    field :mysteries_heading, :string,
      allow_nil?: false,
      description: "The heading over the choice of mysteries."

    field :mysteries_note, :string, allow_nil?: false, description: "The line under it."

    field :before_you_begin, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The paragraphs after the choice."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :first_rosary
end
