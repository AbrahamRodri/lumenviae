defmodule LumenViaeWeb.Live.Pray.AfterPrayerQuoteTest do
  @moduledoc """
  The line for after praying shows its author under it, except Fulton J.
  Sheen's, which is credited in the app's credits only (Abraham, 5 November
  2026: "keep it credit in the credit menu only").
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Pray.Completion
  alias LumenViaeWeb.Live.Pray.Sequence

  defp quote_on(pred) do
    Date.range(~D[2026-01-01], ~D[2026-12-31])
    |> Enum.map(&Sequence.quote_after_praying/1)
    |> Enum.find(pred)
  end

  defp render_quote(quote) do
    (&Completion.after_prayer_quote/1)
    |> render_component(quote: quote)
    |> Floki.parse_fragment!()
  end

  test "a credits-only quote shows its words and no author line" do
    quote = quote_on(& &1["credit_in_credits_only"])
    assert quote["author"] =~ "Sheen"

    doc = render_quote(quote)

    assert Floki.text(Floki.find(doc, "blockquote")) =~ String.slice(quote["text"], 0, 40)
    assert Floki.find(doc, "figcaption") == []
    refute Floki.raw_html(doc) =~ "Sheen"
  end

  test "every other quote keeps its author under it" do
    quote = quote_on(&(!&1["credit_in_credits_only"]))

    doc = render_quote(quote)
    assert Floki.text(Floki.find(doc, "figcaption")) =~ quote["author"]
  end
end
