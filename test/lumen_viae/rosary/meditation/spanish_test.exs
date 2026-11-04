defmodule LumenViae.Rosary.Meditation.SpanishTest do
  @moduledoc """
  The meditations' Spanish (`priv/meditations/es/meditations.json`):
  pinned, and served only while the English it translates is unchanged.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Meditation.Spanish

  # Change the file: bump its updated_at and set the new pair here. Every
  # meditation's source, or its marking as the team's translation, is in
  # priv/meditations/es/SOURCES.md.
  @pinned {~U[2026-11-04 16:16:00Z], "7b142d27434e3137"}

  test "the file is pinned by its date and words" do
    assert {Spanish.updated_at(), Spanish.file_version()} == @pinned, """
    priv/meditations/es/meditations.json changed (now #{DateTime.to_iso8601(Spanish.updated_at())}, #{Spanish.file_version()}).
    Bump its updated_at and set @pinned to the new pair.
    """
  end

  test "the fingerprint is the title and text, so either change moves it" do
    base = Spanish.fingerprint("Title", "Text")

    assert base =~ ~r/^[0-9a-f]{16}$/
    assert Spanish.fingerprint("Title", "Text") == base
    refute Spanish.fingerprint("Title", "Text.") == base
    refute Spanish.fingerprint("Title.", "Text") == base
  end
end
