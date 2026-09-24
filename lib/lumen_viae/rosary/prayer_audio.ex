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
      (`RosaryPrayers.swift`): the Sign of the Cross, the Creed, the Our
      Father, the Hail Mary, the Glory Be, the Fatima Prayer, the Hail Holy
      Queen and the closing prayer. The Hail Mary is recorded once and played
      on every bead.
    * `:announcement` - "The First Joyful Mystery: The Annunciation", one per
      mystery, keyed `"<category>_<order>"` as the app keys `MysteryData`.
    * `:verse` - the Scriptural Rosary's verse for each Hail Mary bead, ten
      per mystery and seven per sorrow, in bead order.

  ## The text is the app's

  The prayer wording is copied from the app's `RosaryPrayers.swift` and
  `RosaryPrayerText`, and the verses are the app's own export
  (`Tools/ScripturalRosary/generate.py` writes
  `scriptural_rosary.json`, copied here verbatim). What is heard has to be
  what is on the screen, so change the two together.

  ## S3 layout

  `voices/<slug>/rosary/<kind>/<name>-<hash>.mp3`. The hash covers the
  spoken text and the voice's synthesis settings, so a reworded prayer or a
  voice moved to another model gets a new key: generation records it
  without `--force`, and a device holding the old file offline sees a new
  filename in the manifest and fetches it, instead of keeping the old
  wording forever. `s3_key/2` is the only place that layout is spelled out.
  """

  alias LumenViae.Rosary.Voices

  defmodule Clip do
    @moduledoc "One recording of the spoken Rosary. See `LumenViae.Rosary.PrayerAudio`."
    @enforce_keys [:kind, :name, :text]
    defstruct [:kind, :name, :text, :mystery, :bead, :reference]

    @type t :: %__MODULE__{
            kind: :prayer | :announcement | :verse,
            name: String.t(),
            text: String.t(),
            mystery: String.t() | nil,
            bead: pos_integer | nil,
            reference: String.t() | nil
          }
  end

  @verses_path Path.join([:code.priv_dir(:lumen_viae), "rosary_audio", "scriptural_rosary.json"])
  @external_resource @verses_path

  @verses @verses_path |> File.read!() |> Jason.decode!()

  # In the order they are said. Line breaks are where the app breaks the
  # lines on screen; `speech_text/1` joins them.
  @prayers [
    {"sign_of_cross", "In the name of the Father, and of the Son, and of the Holy Spirit. Amen."},
    {"apostles_creed",
     """
     I believe in God, the Father almighty, Creator of heaven and earth,
     and in Jesus Christ, His only Son, our Lord,
     who was conceived by the Holy Spirit, born of the Virgin Mary,
     suffered under Pontius Pilate, was crucified, died and was buried;
     He descended into hell;
     on the third day He rose again from the dead;
     He ascended into heaven, and is seated at the right hand of God the Father almighty;
     from there He will come to judge the living and the dead.
     I believe in the Holy Spirit,
     the holy catholic Church, the communion of saints,
     the forgiveness of sins, the resurrection of the body,
     and life everlasting. Amen.
     """},
    {"our_father",
     """
     Our Father, who art in heaven,
     hallowed be Thy name;
     Thy kingdom come;
     Thy will be done on earth as it is in heaven.
     Give us this day our daily bread;
     and forgive us our trespasses
     as we forgive those who trespass against us;
     and lead us not into temptation,
     but deliver us from evil. Amen.
     """},
    {"hail_mary",
     """
     Hail Mary, full of grace, the Lord is with thee;
     blessed art thou among women,
     and blessed is the fruit of thy womb, Jesus.
     Holy Mary, Mother of God,
     pray for us sinners,
     now and at the hour of our death. Amen.
     """},
    {"glory_be",
     """
     Glory be to the Father, and to the Son, and to the Holy Spirit.
     As it was in the beginning, is now, and ever shall be,
     world without end. Amen.
     """},
    {"fatima_prayer",
     """
     O my Jesus, forgive us our sins,
     save us from the fires of hell,
     and lead all souls to heaven,
     especially those in most need of Thy mercy. Amen.
     """},
    {"hail_holy_queen",
     """
     Hail, holy Queen, Mother of mercy,
     our life, our sweetness and our hope.
     To thee do we cry, poor banished children of Eve.
     To thee do we send up our sighs,
     mourning and weeping in this valley of tears.
     Turn, then, most gracious advocate,
     thine eyes of mercy toward us,
     and after this, our exile, show unto us the blessed fruit of thy womb, Jesus.
     O clement, O loving, O sweet Virgin Mary.
     Pray for us, O holy Mother of God,
     that we may be made worthy of the promises of Christ.
     """},
    {"rosary_closing_prayer",
     """
     [Let us pray.]
     O God, whose only-begotten Son,
     by His life, death and resurrection,
     has purchased for us the rewards of eternal life;
     grant, we beseech Thee,
     that meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary,
     we may imitate what they contain
     and obtain what they promise,
     through the same Christ our Lord. Amen.
     """}
  ]

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
  def prayer_ids, do: Enum.map(@prayers, &elem(&1, 0))

  @doc """
  The fixed prayers, in the order they are said.
  """
  @spec prayers() :: [Clip.t()]
  def prayers do
    for {id, text} <- @prayers, do: %Clip{kind: :prayer, name: id, text: String.trim(text)}
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
          nil -> "The #{ordinal} Sorrow: #{name}"
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
  Every clip, or only the kinds named.
  """
  @spec clips([:prayer | :announcement | :verse] | nil) :: [Clip.t()]
  def clips(kinds \\ nil)
  def clips(nil), do: prayers() ++ announcements() ++ verses()

  def clips(kinds) when is_list(kinds) do
    Enum.flat_map(kinds, fn
      :prayer -> prayers()
      :announcement -> announcements()
      :verse -> verses()
    end)
  end

  @doc """
  The kinds, as the slugs the API and the generation task accept.
  """
  @spec kinds() :: %{String.t() => atom}
  def kinds, do: %{"prayers" => :prayer, "announcements" => :announcement, "verses" => :verse}

  @doc """
  What the narrator is sent: the lines of a prayer joined into one flowing
  sentence, and any `[bracketed]` rubric spoken as plain words. Square
  brackets are audio tags to Eleven v3, which would act on `[Let us pray.]`
  rather than say it.
  """
  @spec speech_text(Clip.t()) :: String.t()
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
  The S3 key of a voice's recording of this clip.
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
    |> Enum.map_join("\n", &s3_key(voice, &1))
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
