defmodule LumenViae.Rosary.Types.RosaryReminders do
  @moduledoc """
  The `reminders` section: the daily reminders' messages in their groups, what each intention draws from, and the numbers of the selection rule. See docs/JSON_API.md, "The content document".
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :groups, {:array, Types.ReminderGroup},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The message groups. Titles are under about 35 characters and bodies under about 75, so neither is cut on a lock screen. No message holds a placeholder: each is shown as it is written."

    field :intentions, {:array, Types.ReminderIntention},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "What can draw someone to the Rosary, and the groups each draws its reminders from."

    field :fallback_group, :string,
      allow_nil?: false,
      description: "The group used when no intention was chosen."

    field :week_length, :integer,
      allow_nil?: false,
      description: "The number of reminders scheduled at once, one for each weekday."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_reminders
end
