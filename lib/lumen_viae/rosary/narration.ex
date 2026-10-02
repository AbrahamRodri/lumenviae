defmodule LumenViae.Rosary.Narration do
  @moduledoc """
  One voice's recording of one meditation: the S3 object that exists for
  that pair, and when it was generated.

  A meditation has at most one narration per voice. The voice is the slug
  of a configured `LumenViae.Rosary.Voices` entry rather than a foreign
  key, because voices are configuration, not rows.

  `s3_key` is private: a client is handed a signed URL built from it, never
  the key.

  Mapped onto the existing `meditation_narrations` table exactly as the
  Ecto migrations left it.

  Reach narrations through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type :narration
  end

  postgres do
    table "meditation_narrations"
    repo LumenViae.Repo

    migration_types voice: :string, s3_key: :string
    migration_defaults inserted_at: "nil", updated_at: "nil"

    identity_index_names unique_voice_per_meditation:
                           "meditation_narrations_meditation_id_voice_index"

    references do
      # No index of its own: the unique index on (meditation_id, voice)
      # already leads with the meditation.
      reference :meditation, on_delete: :delete
    end

    custom_indexes do
      index [:voice]
    end
  end

  actions do
    defaults [:read, :destroy]

    read :for_meditation do
      description "One meditation's narrations, oldest first."

      argument :meditation_id, :integer do
        allow_nil? false
      end

      filter expr(meditation_id == ^arg(:meditation_id))
      prepare build(sort: [id: :asc])
    end

    read :in_voice do
      description "Every recording made in one voice."

      argument :voice, :string do
        allow_nil? false
      end

      filter expr(voice == ^arg(:voice))
      prepare build(sort: [id: :asc])
    end

    create :record do
      description "Records that an S3 object now holds one voice's recording of a meditation, replacing any earlier record for the same pair. Called after the upload succeeded, never before: a row here promises an object exists."
      primary? true
      accept [:meditation_id, :voice, :s3_key]

      upsert? true
      upsert_identity :unique_voice_per_meditation
      upsert_fields [:s3_key, :generated_at, :updated_at]

      change set_attribute(:generated_at, &DateTime.utc_now/0)
    end
  end

  # The public may read the recordings of a meditation in circulation: the
  # pages and both APIs sign them into URLs. Recording one is the
  # console's, and the import's and regeneration's on its behalf.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(is_nil(meditation.archived_at))
    end
  end

  validations do
    validate match(:voice, ~r/^[a-z0-9_-]+$/),
      message: "must be a lowercase slug (letters, digits, - and _)"
  end

  attributes do
    integer_primary_key :id

    attribute :voice, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :s3_key, :string do
      allow_nil? false
      constraints max_length: 255, trim?: false
    end

    attribute :generated_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    belongs_to :meditation, LumenViae.Rosary.Meditation do
      attribute_type :integer
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      public? true
    end
  end

  identities do
    identity :unique_voice_per_meditation, [:meditation_id, :voice]
  end
end
