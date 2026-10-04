defmodule LumenViae.Rosary.Types.ReminderGroup do
  @moduledoc """
  A group of reminder messages.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The group's key (`peace`, `habit`, `devotion`, `learning`, `standard`)."

    field :messages, {:array, Types.ReminderMessage},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The group's messages, in the order the rotation counts them."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reminder_group
end
