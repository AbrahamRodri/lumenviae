defmodule LumenViae.Rosary.Meditation do
  @moduledoc """
  A single meditation on one mystery.

  Mapped onto the existing `meditations` table exactly as the Ecto
  migrations left it.

  Reach meditations through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  graphql do
    type :meditation
  end

  postgres do
    table "meditations"
    repo LumenViae.Repo

    migration_types title: :string, author: :string, source: :string
    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      # A mystery with meditations cannot be deleted out from under them.
      reference :mystery, on_delete: :restrict, index?: true
    end

    custom_indexes do
      index [:author]
    end
  end

  actions do
    # archived_at is deliberately in neither accept list: archiving is its
    # own action, so imports and forms cannot flip it.
    defaults [
      :read,
      :destroy,
      create: [:title, :content, :author, :source, :mystery_id, :audio_url, :tts_annotations],
      update: [:title, :content, :author, :source, :mystery_id, :audio_url, :tts_annotations]
    ]
  end

  attributes do
    integer_primary_key :id

    attribute :title, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    # Rendered verbatim (whitespace-pre-wrap) and narrated as written, so it
    # is never trimmed.
    attribute :content, :string do
      allow_nil? false
      public? true
      constraints trim?: false
    end

    attribute :author, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :source, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    # The narration filename, e.g. "Glorious-Fulton-1.mp3", assigned at
    # import. Not a URL and, since narrations gained voices, not a whole S3
    # key either: each voice's object sits at voices/<slug>/<filename> (see
    # LumenViae.Rosary.Voices.narration_key/2), and the narrations
    # relationship says which voices actually have one.
    attribute :audio_url, :string do
      constraints trim?: false
    end

    attribute :archived_at, :utc_datetime

    # Narration pause positions extracted from {pause:N} markers at import
    # time (see LumenViae.Audio.TtsText): a list of
    # %{"offset" => grapheme_offset_into_content, "seconds" => n} maps,
    # consumed only when generating ElevenLabs audio, never rendered.
    attribute :tts_annotations, {:array, :map} do
      allow_nil? false
      default []
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    belongs_to :mystery, LumenViae.Rosary.Mystery do
      attribute_type :integer
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      public? true
    end

    has_many :narrations, LumenViae.Rosary.Narration do
      public? true
    end

    has_many :set_memberships, LumenViae.Rosary.SetMembership do
      public? true
    end

    many_to_many :meditation_sets, LumenViae.Rosary.MeditationSet do
      through LumenViae.Rosary.SetMembership
      join_relationship :set_memberships
      source_attribute_on_join_resource :meditation_id
      destination_attribute_on_join_resource :meditation_set_id
      public? true
    end
  end
end
