defmodule LumenViae.Rosary.RosaryContent.Quotes do
  @moduledoc """
  The `quotes` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s daily quotations and the rule that chooses
  one, shaped as `LumenViae.Rosary.Types.RosaryQuotes`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, _context) do
    quotes = shape(Content.quotes())

    Enum.map(records, fn _record -> quotes end)
  end

  defp shape(%{"rotation" => rotation, "items" => items}) do
    %Types.RosaryQuotes{
      rotation: %Types.QuoteRotation{
        home_offset: rotation["home_offset"],
        after_prayer_offset_divisor: rotation["after_prayer_offset_divisor"]
      },
      items:
        Enum.map(items, fn quote ->
          %Types.RosaryQuote{
            text: quote["text"],
            author: quote["author"],
            source: quote["source"]
          }
        end)
    }
  end
end
