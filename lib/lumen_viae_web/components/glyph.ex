defmodule LumenViaeWeb.Components.Glyph do
  @moduledoc """
  The red liturgical glyphs as markup: ℣ and ℟ are hidden from screen
  readers, which say them in different ways or not at all, and are read
  instead as "Leader:" and "All:", so a person praying with others hears
  which line is theirs. ✠ is drawn as it is.

  Returned as safe markup in one run, with no whitespace around it: the
  Prayer Book, Hours of Prayer and the Missal build their lines as one run
  so a glyph and the stop after it stay together ("℟.").
  """

  @spoken %{"℣" => "Leader:", "℟" => "All:"}

  @doc """
  Runs with the stop after a ℣ or ℟ taken into the glyph (`"℟."`), so it
  is hidden with it: a screen reader says "All: pray for us", not
  "All: . pray for us".
  """
  def with_stops([{:glyph, glyph}, {:text, "." <> rest} | tail]) when is_map_key(@spoken, glyph),
    do: [{:glyph, glyph <> "."} | with_stops(drop_empty([{:text, rest} | tail]))]

  def with_stops([run | tail]), do: [run | with_stops(tail)]
  def with_stops([]), do: []

  defp drop_empty([{:text, ""} | tail]), do: tail
  defp drop_empty(runs), do: runs

  @doc "A glyph's markup (`\"℣\"`, `\"℟.\"`), as iodata of escaped HTML."
  def markup(glyph) do
    case @spoken[String.first(glyph)] do
      nil ->
        [~s(<span class="book-glyph">), escape(glyph), "</span>"]

      spoken ->
        [
          ~s(<span class="book-glyph" aria-hidden="true">),
          escape(glyph),
          ~s(</span><span class="sr-only">),
          spoken,
          " </span>"
        ]
    end
  end

  @doc "What a screen reader says for ℣ or ℟, or nil for any other glyph."
  def spoken(glyph), do: @spoken[glyph]

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
