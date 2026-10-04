defmodule LumenViae.Rosary.RosaryContent.Milestones do
  @moduledoc """
  The `milestones` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s streak milestones, by days ascending, shaped
  as `LumenViae.Rosary.Types.RosaryMilestone`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, _context) do
    milestones =
      Enum.map(Content.milestones(), fn milestone ->
        %Types.RosaryMilestone{
          days: milestone["days"],
          meaning: milestone["meaning"],
          icon: milestone["icon"],
          blessing: milestone["blessing"]
        }
      end)

    Enum.map(records, fn _record -> milestones end)
  end
end
