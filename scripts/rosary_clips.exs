# Every spoken-Rosary clip each narration voice serves, as JSON on stdout,
# for scripts/rosary_lines.py: the voice asked for, the voice that recorded
# it, its hashed file name, kind, name and its words: the text it was sent,
# keeping the text's own line breaks so lines can follow them.
#
#     mix run --no-start scripts/rosary_clips.exs > "$TMPDIR/rosary_clips.json"
alias LumenViae.Rosary.{PrayerAudio, Voices}

for voice <- Voices.list(), clip <- PrayerAudio.clips([:prayer, :announcement, :verse, :book]) do
  served = PrayerAudio.served_voice(voice, clip)

  %{
    asked: voice.slug,
    voice: served.slug,
    file: PrayerAudio.filename(served, clip),
    kind: clip.kind,
    name: clip.name,
    text: String.replace(clip.text, ~r/\[([^\]]*)\]/, "\\1")
  }
end
|> Jason.encode!(pretty: true)
|> IO.puts()
