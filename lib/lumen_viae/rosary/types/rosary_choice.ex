defmodule LumenViae.Rosary.Types.RosaryChoice do
  @moduledoc """
  One of the two choices that change how the Rosary is prayed.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "`audio` or `counting`."

    field :title, :string,
      allow_nil?: false,
      description: "What the choice is called."

    field :icon, :string,
      allow_nil?: false,
      description: "The glyph, by the iOS app's icon name."

    field :options, {:array, Types.RosaryChoiceOption},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The options, the quieter way (value false) first. For a form, use those whose `form` is the form's id, or else `any`."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_choice
end
