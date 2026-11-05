defmodule LumenViae.Rosary.RosaryContent.Quotes do
  @moduledoc """
  The `quotes` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s daily quotations and the rule that chooses
  one, shaped as `LumenViae.Rosary.Types.RosaryQuotes`, in the language
  the read asked for.

  A quote is a plain map, not its typed struct, so `ai_translated` is
  there only on a quote whose Spanish is the team's translation, and
  `credit_in_credits_only` only on the one quote credited in the app's
  credits rather than under it (Fulton J. Sheen's); every other quote
  reads exactly as before.
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
          %{text: quote["text"], author: quote["author"], source: quote["source"]}
          |> put_true(:ai_translated, quote["ai_translated"])
          |> put_true(:credit_in_credits_only, quote["credit_in_credits_only"])
        end)
    }
  end

  # A mark is there only when true, so a quote without it reads exactly as
  # before the mark existed.
  defp put_true(quote, key, true), do: Map.put(quote, key, true)
  defp put_true(quote, _key, _value), do: quote
end
