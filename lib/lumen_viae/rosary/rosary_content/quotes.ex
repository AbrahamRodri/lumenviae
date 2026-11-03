defmodule LumenViae.Rosary.RosaryContent.Quotes do
  @moduledoc """
  The `quotes` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s daily quotations and the rule that chooses
  one, shaped as `LumenViae.Rosary.Types.RosaryQuotes`, in the language
  the read asked for.

  A quote is a plain map, not its typed struct, so `ai_translated` is
  there only on a quote whose Spanish is the team's translation, and an
  English quote reads exactly as before Spanish was served.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  # GraphQL selects only the fields a query names, so the language is
  # asked for here or it would arrive empty.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record -> record.lang |> Content.quotes() |> shape() end)
  end

  defp shape(%{"rotation" => rotation, "items" => items}) do
    %Types.RosaryQuotes{
      rotation: %Types.QuoteRotation{
        home_offset: rotation["home_offset"],
        after_prayer_offset_divisor: rotation["after_prayer_offset_divisor"]
      },
      items:
        Enum.map(items, fn quote ->
          shaped = %{text: quote["text"], author: quote["author"], source: quote["source"]}

          if quote["ai_translated"] == true,
            do: Map.put(shaped, :ai_translated, true),
            else: shaped
        end)
    }
  end
end
