defmodule LumenViae.Rosary.Types.ReminderMessage do
  @moduledoc """
  One reminder: a title and a body, both shown as written.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string,
      allow_nil?: false,
      description: "The notification's title."

    field :body, :string,
      allow_nil?: false,
      description: "The notification's body."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reminder_message
end
