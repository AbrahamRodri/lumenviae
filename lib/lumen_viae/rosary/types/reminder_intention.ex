defmodule LumenViae.Rosary.Types.ReminderIntention do
  @moduledoc """
  What draws someone to the Rosary, chosen in onboarding and used only to personalise copy.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The intention's key (`peace`), which names its groups."

    field :raw_value, :string,
      allow_nil?: false,
      description:
        "The string the iOS app stores for the choice. It never changes, so a client that wants to read an iOS-kept answer can match it."

    field :name, :string,
      allow_nil?: false,
      description: "What the choice is called on screen."

    field :detail, :string,
      allow_nil?: false,
      description: "The line under the name."

    field :groups, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The groups this intention draws from, in order. Someone still learning has not settled into one way of praying, so `learning` lists them all."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :reminder_intention
end
