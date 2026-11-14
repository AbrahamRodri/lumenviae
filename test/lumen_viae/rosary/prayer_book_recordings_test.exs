defmodule LumenViae.Rosary.PrayerBookRecordingsTest do
  @moduledoc """
  The Prayer Book's words on screen (`priv/library/prayer_book.json`) and
  what its recordings say (`priv/rosary_audio/prayer_book.json`) are two
  files. A proofreading edit to one passes every other test, and the app
  then shows one wording and plays another, and lines stop lighting. So
  every recording must say its prayer's English, word for word (case,
  punctuation and spacing aside), except the prayers listed here.

  The exceptions are known and kept on purpose (orch-lead, 7 Nov 2026:
  "list them as known exceptions, so new ones fail; change no text"). No
  prayer is recorded again (no ElevenLabs), so a new difference is fixed
  in the text, or added here with its reason.
  """
  use ExUnit.Case, async: true

  @known %{
    "alma_redemptoris" =>
      "the screen adds the Advent and Christmas-to-Purification verses and prayers",
    "confiteor" => "the screen prints the rubric 'strike the breast three times'",
    "litany_holy_name" => "a litany: the responses are written out for the narrator",
    "litany_loreto" => "a litany: the responses are written out for the narrator",
    "litany_of_humility" => "a litany: the responses are written out for the narrator",
    "litany_sacred_heart" => "a litany: the responses are written out for the narrator",
    "litany_st_joseph" => "a litany: the responses are written out for the narrator",
    "nicene_creed" => "the screen prints the rubric 'here all genuflect'",
    "prayer_for_the_pope" => "the screen prints N. where the Pope's name is said",
    "te_deum" => "the screen prints the rubric 'here all kneel'",
    "the_confession" => "the screen prints the blanks the penitent fills (the time, a sin)",
    "three_hail_marys" => "the screen adds the evening wording ('at night: this night')",
    "veni_creator" =>
      "the screen keeps the correct 'with Thee, O holy Comforter'; the recording says 'Thou'"
  }

  defp read(path), do: Application.app_dir(:lumen_viae, path) |> File.read!() |> Jason.decode!()

  # Words only: case, apostrophes, punctuation, the versicle marks and
  # spacing set aside.
  defp words(text) do
    text
    |> String.downcase()
    |> String.replace(["'", "’"], "")
    |> then(&Regex.scan(~r/[a-z]+/, &1))
    |> List.flatten()
  end

  test "every recording says its prayer's English, but for the known exceptions" do
    recorded = read("priv/rosary_audio/prayer_book.json")["prayers"]
    shown = Map.new(read("priv/library/prayer_book.json")["prayers"], &{&1["id"], &1["english"]})

    differing =
      for %{"id" => id, "text" => text} <- recorded,
          words(text) != words(shown[id] || ""),
          into: MapSet.new(),
          do: id

    new = differing |> MapSet.difference(MapSet.new(Map.keys(@known))) |> Enum.sort()
    gone = @known |> Map.keys() |> MapSet.new() |> MapSet.difference(differing) |> Enum.sort()

    assert new == [],
           "these recordings no longer say their prayer's English: #{inspect(new)}. " <>
             "Fix the text, or list the prayer in @known with its reason."

    assert gone == [],
           "these known exceptions now match; take them out of @known: #{inspect(gone)}"
  end
end
