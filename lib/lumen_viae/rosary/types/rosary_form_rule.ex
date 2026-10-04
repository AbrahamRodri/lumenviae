defmodule LumenViae.Rosary.Types.RosaryFormRule do
  @moduledoc """
  What a form's page carries, depending on the Audio choice.
  """
  use Ash.TypedStruct

  typed_struct do
    field :form, :string,
      allow_nil?: false,
      description: "`meditation`, `scriptural` or `holy`."

    field :when_aloud, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The ids, in order, while the Audio choice is the Whole Rosary. Always the case in the Rosary Said Aloud."

    field :when_silent, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The ids, in order, while it is not."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_form_rule
end
