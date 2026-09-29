defmodule LumenViae.Repo.Migrations.RegisterFrederickNarrations do
  use Ecto.Migration

  @moduledoc """
  Registers Frederick Surrey's recordings of the public catalogue as the
  `frederick` voice (see the :narration_voices config).

  The recordings were made outside the app - Eleven v4 from hand-tagged
  scripts, `priv/narration_scripts/generate_frederick.py` - and uploaded to
  `voices/frederick/<audio filename>`. Before this migration was written,
  every one of these ids was checked against the bucket (a HEAD on
  `voices/frederick/<filename>` for all 121, each the size of the local
  take). A row here promises an object exists, so the list is literal
  rather than "every meditation with audio": meditations outside the public
  sets were not recorded.

  Raw SQL, so this never depends on today's modules. Re-running it leaves
  existing rows as they are.
  """

  @meditation_ids [
    121,
    122,
    123,
    124,
    125,
    126,
    127,
    128,
    129,
    130,
    131,
    132,
    133,
    134,
    135,
    136,
    137,
    138,
    139,
    140,
    141,
    142,
    143,
    144,
    145,
    146,
    147,
    148,
    149,
    150,
    227,
    228,
    229,
    230,
    231,
    246,
    247,
    248,
    249,
    250,
    251,
    252,
    253,
    254,
    255,
    261,
    262,
    263,
    264,
    265,
    296,
    297,
    298,
    299,
    300,
    301,
    302,
    303,
    304,
    305,
    306,
    307,
    308,
    309,
    310,
    311,
    312,
    314,
    315,
    316,
    317,
    318,
    319,
    320,
    326,
    327,
    328,
    329,
    330,
    331,
    332,
    333,
    334,
    335,
    336,
    337,
    338,
    339,
    340,
    341,
    342,
    343,
    344,
    345,
    346,
    347,
    348,
    349,
    350,
    351,
    352,
    353,
    354,
    355,
    356,
    357,
    358,
    359,
    360,
    361,
    362,
    363,
    364,
    365,
    366,
    367,
    368,
    369,
    370,
    371,
    372
  ]

  def up do
    execute """
    INSERT INTO meditation_narrations (meditation_id, voice, s3_key, generated_at, inserted_at, updated_at)
    SELECT id, 'frederick', 'voices/frederick/' || audio_url, NOW(), NOW(), NOW()
    FROM meditations
    WHERE id IN (#{Enum.join(@meditation_ids, ", ")})
      AND audio_url IS NOT NULL AND audio_url <> ''
    ON CONFLICT (meditation_id, voice) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM meditation_narrations WHERE voice = 'frederick'"
  end
end
