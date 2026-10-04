defmodule LumenViae.Rosary.PrayerAudio do
  @moduledoc """
  The spoken Rosary: every recording the app needs to pray a whole Rosary
  aloud, around either a meditation set's narration or the Scriptural
  Rosary's verses.

  A value module. The clips are fixed content, not data anyone edits in
  the admin, so they live here and in `priv/rosary_audio/` rather than in a
  table: changing a prayer is a deploy followed by a generation run
  (`mix lumen_viae.generate_rosary_audio`).

  There are three kinds of clip, each recorded once per narration voice
  (`LumenViae.Rosary.Voices`):

    * `:prayer` - the fixed prayers, keyed by the app's prayer ids
      (`LumenViae.Rosary.Content`): the Sign of the Cross, the Creed, the Our
      Father, the Hail Mary, the Glory Be, the Fatima Prayer, the Hail Holy
      Queen and the closing prayer; the Seven Sorrows chaplet's Act of
      Contrition and closing prayer; and the optional Memorare and Saint
      Michael prayer. The Hail Mary is recorded once and played on every
      bead.
    * `:announcement` - "The First Joyful Mystery: The Annunciation" (or "The
      First Sorrow of Mary: The Prophecy of Simeon"), one per
      mystery, keyed `"<category>_<order>"` as the app keys `MysteryData`.
    * `:verse` - the Scriptural Rosary's verse for each Hail Mary bead, ten
      per mystery and seven per sorrow, in bead order.
    * `:book` - the app's Prayer Book: Morning and Night Prayers, the
      Angelus, the prayers before and after Mass and Confession, Our
      Lady's antiphons and litanies, keyed by the book's prayer ids. The
      app's `Tools/PrayerBook/export.py` writes `prayer_book.json`, already
      in the words a narrator says (litany responses after every
      invocation, the book's marks taken out), copied here verbatim. The
      Rosary's own prayers are not in it: the book plays the `:prayer`
      recordings for those. Served only when asked for (`include=book`),
      so the spoken Rosary's manifest and its `version` are as they were.

  ## The words are the server's

  The prayers' words are `LumenViae.Rosary.Content`'s
  (`priv/rosary_content/prayers.json`), which `GET /api/v2/rosary-content`
  serves as text: what is heard is what is on the screen because both read
  the same file. The iOS app's `RosaryPrayers.swift` is its offline copy of
  them. The verses are still the app's own export
  (`Tools/ScripturalRosary/generate.py` writes `scriptural_rosary.json`,
  copied here verbatim). A changed word is a clip to record again; see
  docs/SPOKEN_ROSARY.md.

  ## S3 layout

  `voices/<slug>/rosary/<kind>/<name>-<hash>.mp3`. The hash covers the
  spoken text and the voice's synthesis settings, so a reworded prayer or a
  voice moved to another model gets a new key: generation records it
  without `--force`, and a device holding the old file offline sees a new
  filename in the manifest and fetches it, instead of keeping the old
  wording forever. `s3_key/2` is the only place that layout is spelled out.

  ## Borrowed recordings

  A voice may not have recorded every kind of clip: a voice added after the
  spoken Rosary was recorded names, in its `rosary_audio_from`, the voice
  whose recordings stand in for each kind it lacks. `s3_key/2` is always a
  voice's *own* key - what generation writes. What a client is handed is
  `served_key/2` and `served_filename/2`, which follow the borrow, and
  `version/2` fingerprints those, so recording a voice's own clips later
  and dropping the borrow from config changes the version and devices
  fetch the new files.
  """

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Voices

  defmodule Clip do
    @moduledoc "One recording of the spoken Rosary. See `LumenViae.Rosary.PrayerAudio`."
    @enforce_keys [:kind, :name, :text]
    defstruct [:kind, :name, :text, :mystery, :bead, :reference, :title]

    @type t :: %__MODULE__{
            kind: :prayer | :announcement | :verse | :book,
            name: String.t(),
            text: String.t(),
            mystery: String.t() | nil,
            bead: pos_integer | nil,
            reference: String.t() | nil,
            title: String.t() | nil
          }
  end

  @verses_path Path.join([:code.priv_dir(:lumen_viae), "rosary_audio", "scriptural_rosary.json"])
  @external_resource @verses_path

  @verses @verses_path |> File.read!() |> Jason.decode!()

  @book_path Path.join([:code.priv_dir(:lumen_viae), "rosary_audio", "prayer_book.json"])
  @external_resource @book_path

  @book @book_path |> File.read!() |> Jason.decode!() |> Map.fetch!("prayers")

  # The mystery names exactly as the app's MysteryData carries them, in
  # order within each category.
  @mysteries [
    {"joyful", "Joyful",
     [
       "The Annunciation",
       "The Visitation",
       "The Nativity",
       "The Presentation",
       "The Finding in the Temple"
     ]},
    {"sorrowful", "Sorrowful",
     [
       "The Agony in the Garden",
       "The Scourging at the Pillar",
       "The Crowning with Thorns",
       "The Carrying of the Cross",
       "The Crucifixion"
     ]},
    {"glorious", "Glorious",
     [
       "The Resurrection",
       "The Ascension",
       "The Descent of the Holy Spirit",
       "The Assumption",
       "The Coronation"
     ]},
    {"luminous", "Luminous",
     [
       "The Baptism in the Jordan",
       "The Wedding at Cana",
       "The Proclamation of the Kingdom",
       "The Transfiguration",
       "The Institution of the Eucharist"
     ]},
    {"seven_sorrows", nil,
     [
       "The Prophecy of Simeon",
       "The Flight into Egypt",
       "The Loss of Jesus in the Temple",
       "Mary Meets Jesus Carrying the Cross",
       "The Crucifixion",
       "Jesus Taken Down from the Cross",
       "The Burial of Jesus"
     ]}
  ]

  @ordinals ~w(First Second Third Fourth Fifth Sixth Seventh)

  @doc """
  The prayer ids, in the order they are said.
  """
  @spec prayer_ids() :: [String.t()]
  def prayer_ids, do: Content.prayer_ids()

  @doc """
  The fixed prayers, in the order they are said: the English of
  `LumenViae.Rosary.Content`'s prayers, its lines joined by newlines as the
  app breaks them on screen. `speech_text/1` joins them into one sentence.
  """
  @spec prayers() :: [Clip.t()]
  def prayers do
    for %{"id" => id, "text" => %{"en" => lines}} <- Content.prayers() do
      %Clip{kind: :prayer, name: id, text: Enum.join(lines, "\n")}
    end
  end

  @doc """
  One announcement per mystery, in category then mystery order.
  """
  @spec announcements() :: [Clip.t()]
  def announcements do
    for {category, label, names} <- @mysteries,
        {name, index} <- Enum.with_index(names) do
      ordinal = Enum.at(@ordinals, index)
      key = "#{category}_#{index + 1}"

      text =
        case label do
          nil -> "The #{ordinal} Sorrow of Mary: #{name}"
          label -> "The #{ordinal} #{label} Mystery: #{name}"
        end

      %Clip{kind: :announcement, name: key, mystery: key, text: text}
    end
  end

  @doc """
  The Scriptural Rosary's verses, one per Hail Mary bead, in mystery then
  bead order.
  """
  @spec verses() :: [Clip.t()]
  def verses do
    for {category, _label, names} <- @mysteries,
        key <- Enum.map(1..length(names), &"#{category}_#{&1}"),
        {%{"reference" => reference, "text" => text}, bead} <-
          Enum.with_index(Map.fetch!(@verses, key), 1) do
      %Clip{
        kind: :verse,
        name: "#{key}_#{bead}",
        mystery: key,
        bead: bead,
        reference: reference,
        text: text
      }
    end
  end

  @doc """
  The Prayer Book's prayers, one clip each, in the export's order (by id).
  """
  @spec book() :: [Clip.t()]
  def book do
    for %{"id" => id, "title" => title, "text" => text} <- @book do
      %Clip{kind: :book, name: id, title: title, text: String.trim(text)}
    end
  end

  @doc """
  The spoken Rosary's clips, or only the kinds named. The Prayer Book's
  are not the Rosary's and are left out unless named.
  """
  @spec clips([:prayer | :announcement | :verse | :book] | nil) :: [Clip.t()]
  def clips(kinds \\ nil)
  def clips(nil), do: prayers() ++ announcements() ++ verses()

  def clips(kinds) when is_list(kinds) do
    Enum.flat_map(kinds, fn
      :prayer -> prayers()
      :announcement -> announcements()
      :verse -> verses()
      :book -> book()
    end)
  end

  @doc """
  The kinds, as the slugs the API and the generation task accept.
  """
  @spec kinds() :: %{String.t() => atom}
  def kinds,
    do: %{
      "prayers" => :prayer,
      "announcements" => :announcement,
      "verses" => :verse,
      "book" => :book
    }

  @doc """
  The order a whole spoken Rosary is said in, for a set in `category` with
  `decades` meditations - the same order as the app's
  `SpokenRosaryScript`, so the site and the app pray alike.

  Each step is a map with `kind` (`:prayer`, `:announcement` or
  `:meditation`), `name` (the prayer id, or the announcement's
  `"<category>_<order>"`), `decade` (0-based, `nil` outside the decades),
  `caption` and `pause_ms`, the silence after it. A `:meditation` step is
  the set's own narration for that decade, which the caller resolves.

  `orders` are the mysteries' `order` values in prayer order, since a set's
  meditations need not start at the first mystery. Options:

    * `:style` - `:meditation` (default) says each set's meditation after
      its announcement; `:plain` is the app's "Rosary Aloud", the prayers
      alone with no meditation step.
    * `:closing` - optional prayers after the closing prayer, any of
      `:holy_father`, `:memorare`, `:st_michael`, said in that order.
      Ignored for the Seven Sorrows chaplet.

  The four Rosaries open with the Creed, an Our Father, three Hail Marys
  and a Glory Be, and give each decade ten Hail Marys, a Glory Be and the
  Fatima Prayer. The Seven Sorrows chaplet is the Servite form: an Act of
  Contrition to open, seven Hail Marys and a Glory Be to each sorrow and no
  Fatima Prayer, then three Hail Marys for Our Lady's tears and its own
  closing prayer.
  """
  @spec script(String.t(), [pos_integer], keyword) :: [map]
  def script(category, orders, opts \\ []) do
    chaplet? = category == "seven_sorrows"
    plain? = Keyword.get(opts, :style, :meditation) == :plain

    opening =
      if chaplet? do
        [
          step("sign_of_cross", "The Sign of the Cross"),
          step("act_of_contrition", "Act of Contrition", 1500)
        ]
      else
        [
          step("sign_of_cross", "The Sign of the Cross"),
          step("apostles_creed", "The Apostles' Creed"),
          step("our_father", "Our Father"),
          step("hail_mary", "Hail Mary for an increase of faith"),
          step("hail_mary", "Hail Mary for an increase of hope"),
          step("hail_mary", "Hail Mary for an increase of charity"),
          step("glory_be", "Glory Be", 1500)
        ]
      end

    hail_marys = if chaplet?, do: 7, else: 10

    decades =
      orders
      |> Enum.with_index()
      |> Enum.flat_map(fn {order, decade} ->
        key = "#{category}_#{order}"

        announcement = %{
          kind: :announcement,
          name: key,
          caption: announcement_text(key),
          pause_ms: 1500
        }

        meditation =
          if plain?,
            do: [],
            else: [%{kind: :meditation, name: key, caption: "Meditation", pause_ms: 1500}]

        beads =
          for n <- 1..hail_marys, do: step("hail_mary", "Hail Mary #{n} of #{hail_marys}")

        ending =
          if chaplet?,
            do: [step("glory_be", "Glory Be", 2000)],
            else: [step("glory_be", "Glory Be"), step("fatima_prayer", "Fatima Prayer", 2000)]

        ([announcement | meditation] ++ [step("our_father", "Our Father")] ++ beads ++ ending)
        |> Enum.map(&Map.put(&1, :decade, decade))
      end)

    closing =
      if chaplet? do
        for(n <- 1..3, do: step("hail_mary", "Hail Mary for her tears, #{n} of 3")) ++
          [
            step("sorrows_closing_prayer", "Closing Prayer", 1500),
            step("sign_of_cross", "The Sign of the Cross")
          ]
      else
        extras = Keyword.get(opts, :closing, [])

        [
          step("hail_holy_queen", "Hail, Holy Queen"),
          step("rosary_closing_prayer", "Closing Prayer", 1500)
        ] ++
          if(:holy_father in extras,
            do: [
              step("our_father", "For the intentions of the Holy Father"),
              step("hail_mary", "For the intentions of the Holy Father"),
              step("glory_be", "For the intentions of the Holy Father", 1500)
            ],
            else: []
          ) ++
          if(:memorare in extras, do: [step("memorare", "The Memorare", 1500)], else: []) ++
          if(:st_michael in extras,
            do: [step("st_michael_prayer", "Prayer to Saint Michael", 1500)],
            else: []
          ) ++
          [step("sign_of_cross", "The Sign of the Cross")]
      end

    opening ++ decades ++ closing
  end

  defp step(name, caption, pause_ms \\ 700),
    do: %{kind: :prayer, name: name, caption: caption, pause_ms: pause_ms, decade: nil}

  defp announcement_text(key) do
    Enum.find_value(announcements(), key, &(&1.mystery == key && &1.text))
  end

  @doc """
  The clip a script step plays, or `nil` for a meditation step, whose
  audio is the set's own narration rather than part of this catalogue.
  """
  @spec clip_for_step(map) :: Clip.t() | nil
  def clip_for_step(%{kind: :prayer, name: name}), do: Enum.find(prayers(), &(&1.name == name))

  def clip_for_step(%{kind: :announcement, name: name}),
    do: Enum.find(announcements(), &(&1.mystery == name))

  def clip_for_step(%{kind: :meditation}), do: nil

  @doc """
  What the narrator is sent: the lines of a prayer joined into one flowing
  sentence, and any `[bracketed]` rubric spoken as plain words. Square
  brackets are audio tags to Eleven v3, which would act on `[Let us pray.]`
  rather than say it.
  """
  @spec speech_text(Clip.t()) :: String.t()
  def speech_text(%Clip{kind: :book, text: text}) do
    # A book prayer keeps its stanzas apart: each blank line becomes the
    # voice's own pause when the pipeline prepares it
    text
    |> String.replace(~r/\[([^\]]*)\]/, "\\1")
    |> String.split(~r/\n\s*\n/, trim: true)
    |> Enum.map_join("\n\n", fn stanza ->
      stanza |> String.split("\n", trim: true) |> Enum.map_join(" ", &String.trim/1)
    end)
  end

  def speech_text(%Clip{text: text}) do
    text
    |> String.replace(~r/\[([^\]]*)\]/, "\\1")
    |> String.split("\n", trim: true)
    |> Enum.map_join(" ", &String.trim/1)
  end

  @doc """
  The file a voice's recording of this clip is stored as:
  `<name>-<hash>.mp3`. See "S3 layout" above for why it carries a hash.
  """
  @spec filename(Voices.Voice.t(), Clip.t()) :: String.t()
  def filename(%Voices.Voice{} = voice, %Clip{} = clip) do
    "#{clip.name}-#{fingerprint(voice, clip)}.mp3"
  end

  @doc """
  The voice whose recording of `clip` is served for `voice`: `voice`
  itself, or the voice its `rosary_audio_from` names for the clip's kind.
  """
  @spec served_voice(Voices.Voice.t(), Clip.t()) :: Voices.Voice.t()
  def served_voice(%Voices.Voice{rosary_audio_from: from} = voice, %Clip{kind: kind}) do
    case Map.get(from || %{}, kind) do
      nil -> voice
      slug -> Voices.get(slug) || voice
    end
  end

  @doc """
  The S3 key a client is served for `voice`'s recording of `clip`. See
  "Borrowed recordings" above.
  """
  @spec served_key(Voices.Voice.t(), Clip.t()) :: String.t()
  def served_key(voice, clip), do: s3_key(served_voice(voice, clip), clip)

  @doc """
  The file name a client is served for `voice`'s recording of `clip`.
  """
  @spec served_filename(Voices.Voice.t(), Clip.t()) :: String.t()
  def served_filename(voice, clip), do: filename(served_voice(voice, clip), clip)

  @doc """
  The S3 key of a voice's own recording of this clip - what generation
  writes. Clients are handed `served_key/2`.
  """
  @spec s3_key(Voices.Voice.t(), Clip.t()) :: String.t()
  def s3_key(%Voices.Voice{slug: slug} = voice, %Clip{kind: kind} = clip) do
    "voices/#{slug}/rosary/#{kind}s/#{filename(voice, clip)}"
  end

  @doc """
  A short fingerprint of everything that decides one voice's catalogue.
  Changes whenever any clip would be recorded differently, so a client can
  compare it against the one its offline copy was downloaded under.
  """
  @spec version(Voices.Voice.t(), [Clip.t()]) :: String.t()
  def version(%Voices.Voice{} = voice, clips) do
    clips
    |> Enum.map_join("\n", &served_key(voice, &1))
    |> hash()
  end

  defp fingerprint(voice, clip) do
    settings =
      voice.voice_settings |> Enum.sort() |> Enum.map_join(",", fn {k, v} -> "#{k}=#{v}" end)

    hash(
      Enum.join(
        [voice.eleven_labs_voice_id, voice.model_id, settings, speech_text(clip)],
        "\u0000"
      )
    )
  end

  defp hash(value) do
    :crypto.hash(:sha256, value) |> Base.encode16(case: :lower) |> binary_part(0, 10)
  end
end
