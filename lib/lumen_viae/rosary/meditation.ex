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
    # Deleting a meditation takes its narrations and its set memberships
    # with it: both foreign keys cascade.
    defaults [:read, :destroy]

    read :detailed do
      description "Every meditation, oldest first, with its mystery and its narrations."
      prepare build(sort: [id: :asc], load: [:mystery, :narrations])
    end

    read :with_audio_filenames do
      description "The meditations that already claim any of the given audio filenames."

      argument :audio_urls, {:array, :string} do
        allow_nil? false
      end

      filter expr(audio_url in ^arg(:audio_urls))
      prepare build(sort: [id: :asc])
    end

    read :archived do
      description "The meditations taken out of circulation."
      filter expr(archived?)
      prepare build(sort: [id: :asc])
    end

    read :active_in_no_set do
      description "Active meditations that belong to no meditation set."
      filter expr(not archived? and not exists(set_memberships, true))
      prepare build(sort: [id: :asc])
    end

    read :public_missing_audio do
      description "Active meditations with no audio filename that someone can reach: they are in at least one set that is not hidden."

      filter expr(
               not archived? and not has_audio? and
                 exists(
                   meditation_sets,
                   not exists(meditations, not is_nil(archived_at))
                 )
             )

      prepare build(sort: [id: :asc])
    end

    read :missing_a_voice do
      description "Active meditations with an audio filename that lack a recording in at least one of the given voices."

      argument :voices, {:array, :string} do
        allow_nil? false
      end

      filter expr(
               not archived? and has_audio? and
                 count(narrations, query: [filter: expr(voice in ^arg(:voices))]) <
                   length(^arg(:voices))
             )

      prepare build(sort: [id: :asc])
    end

    # archived_at is in neither accept list: archiving is its own action,
    # so imports and forms cannot flip it.
    create :create do
      primary? true
      accept [:title, :content, :author, :source, :mystery_id, :audio_url, :tts_annotations]
      validate LumenViae.Rosary.Meditation.NoNarrationMarkup
    end

    update :update do
      primary? true
      accept [:title, :content, :author, :source, :mystery_id, :audio_url, :tts_annotations]

      # ResetStaleAnnotations compares the new content with the stored one,
      # so this update needs the record rather than a bare UPDATE.
      require_atomic? false
      validate LumenViae.Rosary.Meditation.NoNarrationMarkup
      change LumenViae.Rosary.Meditation.ResetStaleAnnotations
    end

    update :archive do
      description "Archives a meditation without deleting it. It stays fully editable in the admin, but it leaves every public surface, and any set containing it is hidden from public listings and the API."
      accept []
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end

    update :unarchive do
      description "Restores an archived meditation, making it (and its sets) public again."
      accept []
      change set_attribute(:archived_at, nil)
    end
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

    # Oldest first, which is the order the recordings were made in.
    has_many :narrations, LumenViae.Rosary.Narration do
      sort id: :asc
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
      sort id: :asc
      public? true
    end
  end

  calculations do
    calculate :archived?, :boolean, expr(not is_nil(archived_at)) do
      description "Whether the meditation has been taken out of circulation."
    end

    # A blank filename is the same as none: older rows carry an empty
    # string where newer ones carry null.
    calculate :has_audio?, :boolean, expr(not is_nil(audio_url) and audio_url != "") do
      description "Whether the meditation has an audio filename, and so is expected to have a recording in every voice."
    end
  end
end
