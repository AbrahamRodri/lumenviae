defmodule LumenViae.Rosary.PrayerAudioLinesTest do
  @moduledoc """
  The spoken Rosary's lines (`priv/rosary_audio/lines/<voice>.json`): each
  timed recording is one a voice really serves, its lines fit inside the
  recording, one after another, and together say exactly the clip's words.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.{PrayerAudio, Voices}

  @kinds [:prayer, :announcement, :verse, :book]

  # Every recording a voice serves, by the voice that recorded it: slug =>
  # file name => clip.
  defp served do
    for voice <- Voices.list(),
        clip <- PrayerAudio.clips(@kinds),
        recorded_by = PrayerAudio.served_voice(voice, clip),
        reduce: %{} do
      acc ->
        put_in(
          acc,
          [Access.key(recorded_by.slug, %{}), PrayerAudio.filename(recorded_by, clip)],
          clip
        )
    end
  end

  defp words(text) do
    ~r/[[:alnum:]]+(?:['’][[:alpha:]]+)*/u
    |> Regex.scan(String.downcase(text))
    |> List.flatten()
  end

  test "every timed recording is one a voice serves" do
    served = served()

    for {slug, files} <- PrayerAudio.timed_lines(), file <- Map.keys(files) do
      assert get_in(served, [slug, file]), "#{slug}/#{file} is not a recording any voice serves"
    end
  end

  test "each clip's lines fit its length, in order and without overlap" do
    for {slug, files} <- PrayerAudio.timed_lines(), {file, timed} <- files do
      label = "#{slug}/#{file}"
      assert timed.duration > 0, label
      assert timed.lines != [], label

      Enum.reduce(timed.lines, 0.0, fn line, previous_end ->
        assert line.text != "", label
        assert line.start >= previous_end, "#{label}: '#{line.text}' starts before the last ends"
        assert line.start < line.end, "#{label}: '#{line.text}' ends before it starts"

        assert line.end <= timed.duration + 0.01,
               "#{label}: '#{line.text}' ends after the recording"

        line.end
      end)
    end
  end

  test "a clip's lines say exactly its words, in order" do
    served = served()

    for {slug, files} <- PrayerAudio.timed_lines(), {file, timed} <- files do
      clip = get_in(served, [slug, file])
      assert words(Enum.map_join(timed.lines, " ", & &1.text)) == words(clip.text), file
    end
  end

  test "lines follow a borrowed recording, and a clip not timed has none" do
    for voice <- Voices.list(), clip <- PrayerAudio.clips(@kinds) do
      recorded_by = PrayerAudio.served_voice(voice, clip)

      timed =
        get_in(PrayerAudio.timed_lines(), [
          recorded_by.slug,
          PrayerAudio.filename(recorded_by, clip)
        ])

      assert PrayerAudio.lines(voice, clip) == (timed && timed.lines)
    end

    reworded = %PrayerAudio.Clip{
      kind: :prayer,
      name: "hail_mary",
      text: "Not the words recorded."
    }

    assert PrayerAudio.lines(Voices.default(), reworded) == nil
  end
end
