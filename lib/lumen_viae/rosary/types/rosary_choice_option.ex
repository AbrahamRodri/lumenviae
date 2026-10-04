defmodule LumenViae.Rosary.Types.RosaryChoiceOption do
  @moduledoc """
  One option of a choice, as it is named and explained for a form.
  """
  use Ash.TypedStruct

  typed_struct do
    field :form, :string,
      allow_nil?: false,
      description:
        "`meditation`, `scriptural` or `any`. Audio is named and explained differently for a meditation set and for the Scriptural Rosary; Counting is the same for both (`any`)."

    field :value, :boolean,
      allow_nil?: false,
      description:
        "The setting's value: Audio's is true for the Whole Rosary, Counting's true for the beads on the screen."

    field :name, :string,
      allow_nil?: false,
      description: "What the option is called."

    field :note, :string,
      allow_nil?: false,
      description: "What the chosen option does, as what is heard or seen."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_choice_option
end
