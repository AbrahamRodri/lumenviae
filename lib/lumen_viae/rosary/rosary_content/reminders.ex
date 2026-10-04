defmodule LumenViae.Rosary.RosaryContent.Reminders do
  @moduledoc """
  The `reminders` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s reminder messages, the intentions that
  choose among them and the numbers of the selection rule, shaped as
  `LumenViae.Rosary.Types.RosaryReminders`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, _context) do
    reminders = shape(Content.reminders())

    Enum.map(records, fn _record -> reminders end)
  end

  defp shape(reminders) do
    %Types.RosaryReminders{
      groups:
        Enum.map(reminders["groups"], fn group ->
          %Types.ReminderGroup{
            id: group["id"],
            messages:
              Enum.map(
                group["messages"],
                &%Types.ReminderMessage{title: &1["title"], body: &1["body"]}
              )
          }
        end),
      intentions:
        Enum.map(reminders["intentions"], fn intention ->
          %Types.ReminderIntention{
            id: intention["id"],
            raw_value: intention["raw_value"],
            name: intention["name"],
            detail: intention["detail"],
            groups: intention["groups"]
          }
        end),
      fallback_group: reminders["fallback_group"],
      week_length: reminders["week_length"]
    }
  end
end
