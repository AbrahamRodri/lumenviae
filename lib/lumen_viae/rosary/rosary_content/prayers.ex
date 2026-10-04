defmodule LumenViae.Rosary.RosaryContent.Prayers do
  @moduledoc """
  The `prayers` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s prayers, in the order they are said, shaped
  as `LumenViae.Rosary.Types.RosaryPrayer`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, _context) do
    prayers = Enum.map(Content.prayers(), &shape/1)

    Enum.map(records, fn _record -> prayers end)
  end

  defp shape(%{"id" => id, "group" => group, "title" => title, "text" => text}) do
    %Types.RosaryPrayer{
      id: id,
      group: group,
      title: %Types.PrayerTitle{en: title["en"], la: title["la"]},
      text: %Types.PrayerText{en: text["en"], la: text["la"]}
    }
  end
end
