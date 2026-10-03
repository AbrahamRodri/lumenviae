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
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource, AshPaperTrail.Resource]

  # GraphQL shows a meditation's text, its mystery and its narrations as
  # signed URLs. The narrations relationship (S3 keys, not URLs) and the
  # path to sets stay out of the type; `narrations` in GraphQL is the
  # signed_narrations calculation. See docs/GRAPHQL.md.
  graphql do
    type :meditation
    relationships [:mystery]
    hide_fields [:mystery_id]
    field_names signed_narrations: :narrations
    derive_filter? false
    derive_sort? false
  end

  # The JSON:API shows what GraphQL shows, but for narration(preferring:).
  # A calculation's argument travels in a field_inputs query parameter that
  # the OpenAPI document cannot describe, so a generated client could never
  # say which voice it prefers; it reads `narrations`, or asks
  # POST /api/v2/meditations/audio with its voice. The signed field is not
  # a default: a client names it in fields[meditation]=, so a shelf that
  # does not ask has nothing signed on its behalf. narrated_voices signs
  # nothing and is a default.
  json_api do
    type "meditation"

    show_fields [
      :title,
      :content,
      :author,
      :source,
      :mystery,
      :narrated_voices,
      :signed_narrations
    ]

    default_fields [:title, :content, :author, :source, :narrated_voices]
    field_names signed_narrations: :narrations
    derive_filter? false
    derive_sort? false
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

  # Every create, update and destroy leaves a version row holding the whole
  # record as it stood afterwards (or, for a destroy, as it stood last), so
  # an edit can always be seen and reversed. The action that made it is
  # stored with it. The two timestamps are left out because they change
  # with every write and say nothing a version's own timestamp does not;
  # the primary key is left out by the extension.
  #
  # No foreign key from a version to its record: the record can really be
  # deleted, and its versions are the one place its last state survives.
  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]
    reference_source? false

    # Admin-only, read-only history. See LumenViae.Rosary.VersionPolicies.
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin LumenViae.Rosary.VersionPolicies
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
      description "The meditations that already claim any of the given audio filenames: recorded under it (audio_url), or meant to be (narration_filename)."

      argument :audio_urls, {:array, :string} do
        allow_nil? false
      end

      filter expr(audio_url in ^arg(:audio_urls) or narration_filename in ^arg(:audio_urls))
      prepare build(sort: [id: :asc])
    end

    read :archived do
      description "The meditations taken out of circulation."
      filter expr(archived?)
      prepare build(sort: [id: :asc])
    end

    read :active_in_no_set do
      description "Active meditations that belong to no meditation set."
      filter expr(not archived? and not in_any_set?)
      prepare build(sort: [id: :asc])
    end

    read :public_missing_audio do
      description "Active meditations with no audio filename that someone can reach: they are in at least one set that is not hidden."

      filter expr(not archived? and not has_audio? and in_a_visible_set?)

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

      accept [
        :title,
        :content,
        :author,
        :source,
        :mystery_id,
        :audio_url,
        :narration_filename,
        :tts_annotations
      ]

      validate LumenViae.Rosary.Meditation.NoNarrationMarkup
    end

    update :update do
      primary? true

      accept [
        :title,
        :content,
        :author,
        :source,
        :mystery_id,
        :audio_url,
        :narration_filename,
        :tts_annotations
      ]

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

    action :audio_for, {:array, LumenViae.Rosary.Types.MeditationNarration} do
      # Nullable at the GraphQL root, so a signing outage here leaves the
      # rest of a combined document its data.
      allow_nil? true

      description "Freshly signed narrations for meditations by id, in the order asked, each in the preferred voice where it has one. An id with nothing to play is left out."

      constraints nil_items?: false

      argument :meditation_ids, {:array, LumenViae.Rosary.Types.Id} do
        allow_nil? false
        constraints max_length: 200, nil_items?: false
      end

      argument :voice, :string do
        description "The voice preferred, a slug. A meditation it has not recorded, or an unknown slug, is answered in the default voice; each answer names the voice served."
      end

      run LumenViae.Rosary.Meditation.AudioFor
    end
  end

  # The public may read a meditation that is in circulation, by any read:
  # an archived one is invisible to it, which is what every public surface
  # already serves (a set holding one is hidden, and its audio answers
  # not-found). `audio_for` is GraphQL's meditationAudio; it reads the
  # meditations as its caller, so the same rule applies inside it.
  # Everything else is the console's.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action(:audio_for) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(is_nil(archived_at))
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

    # The filename this meditation's narrations are recorded under
    # (voices/<slug>/<narration_filename>), set by the import when the row
    # is written. `audio_url` says a recording exists and is set only when
    # the first one lands; this says which file was meant, so a meditation
    # whose every voice failed can still be recorded later
    # (`regenerate_audio --only-missing`), and an import can see a filename
    # another meditation has claimed but not yet recorded. Internal: no
    # API shows it.
    attribute :narration_filename, :string do
      public? false
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

    calculate :signed_narrations,
              {:array, LumenViae.Rosary.Types.SignedNarration},
              LumenViae.Rosary.Meditation.SignedNarrations do
      public? true
      constraints nil_items?: false

      description "Every recording of the meditation as a playable URL, the default voice first. Empty when nothing is recorded; null when recordings exist but cannot be signed just now (see narratedVoices)."
    end

    calculate :narrated_voices,
              {:array, :string},
              LumenViae.Rosary.Meditation.NarratedVoices do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The voices that have recorded the meditation, default first. Signs nothing."
    end

    calculate :narration,
              LumenViae.Rosary.Types.SignedNarration,
              LumenViae.Rosary.Meditation.PreferredNarration do
      public? true

      description "The recording to play for a listener who prefers a voice: that voice if it has recorded the meditation, otherwise the default. `preferring` is a voice slug: a retired voice means its successor, an unknown one is ignored. Null when nothing is recorded, or when it cannot be signed just now; narratedVoices tells the two apart."

      argument :preferring, :string
    end
  end

  # What the admin reports above ask about sets. Unauthorized for the
  # reason `MeditationSet.visible?` is: the answer must not change with
  # who asks, and an authorized exists over rows the actor cannot read
  # would quietly be false.
  aggregates do
    exists :in_any_set?, :set_memberships do
      authorize? false
    end

    exists :in_a_visible_set?, :meditation_sets do
      filter expr(visible?)
      authorize? false
    end
  end
end
