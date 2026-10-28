defmodule LumenViae.Ops.ErrorLine do
  @moduledoc """
  An error message cut to the one line that says what went wrong, for a
  log line or `/ops/status`.

  Most messages say it first. An Ash error does not: its message starts
  with a blank line and a header ("Invalid Error", "Bread Crumbs:"), and
  each cause follows on a line of its own beginning `* `. So the first
  such cause wins, and otherwise the first line with words on it.
  """

  @spec summary(String.t(), pos_integer) :: String.t()
  def summary(text, max \\ 200) do
    lines = text |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    line =
      case Enum.find(lines, &String.starts_with?(&1, "* ")) do
        "* " <> cause -> cause
        nil -> List.first(lines, "")
      end

    String.slice(line, 0, max)
  end
end
