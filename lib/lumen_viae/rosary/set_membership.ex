defmodule LumenViae.Rosary.SetMembership do
  @moduledoc """
  One meditation's place in one meditation set.

  The join row carries the meditation's `order` within the set, which is why
  membership is a resource in its own right rather than a bare many-to-many.

  Mapped onto the existing `meditation_set_meditations` table exactly as the
  Ecto migrations left it.

  Reach memberships through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  graphql do
    type :set_membership
  end

  postgres do
    table "meditation_set_meditations"
    repo LumenViae.Repo

    # Ash would make an :integer attribute a bigint; `order` is an int4.
    migration_types order: :integer
    migration_defaults inserted_at: "nil", updated_at: "nil"

    # The first name is what Postgres actually holds: the migration asked
    # for a 64-character index name and Postgres keeps 63.
    identity_index_names unique_meditation_per_set:
                           "meditation_set_meditations_meditation_set_id_meditation_id_inde",
                         unique_order_per_set:
                           "meditation_set_meditations_meditation_set_id_order_index"

    references do
      reference :meditation_set, on_delete: :delete, index?: true
      reference :meditation, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:meditation_set_id, :meditation_id, :order],
      update: [:order]
    ]

    read :in_set do
      description "One set's memberships, in the order the set is prayed."

      argument :meditation_set_id, :integer do
        allow_nil? false
      end

      filter expr(meditation_set_id == ^arg(:meditation_set_id))
      prepare build(sort: [order: :asc])
    end

    read :in_prayer_order do
      description "Every membership, each set's in the order it is prayed."
      prepare build(sort: [meditation_set_id: :asc, order: :asc])
    end

    read :holding_archived do
      description "The memberships of archived meditations: each one is a reason its set is hidden."
      filter expr(not is_nil(meditation.archived_at))
      prepare build(sort: [id: :asc])
    end
  end

  # A set is at most seven meditations long (the Seven Sorrows), and prayer
  # positions count from one.
  validations do
    validate numericality(:order, greater_than: 0)
    validate numericality(:order, less_than_or_equal_to: 7)
  end

  attributes do
    integer_primary_key :id

    attribute :order, :integer do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    belongs_to :meditation_set, LumenViae.Rosary.MeditationSet do
      attribute_type :integer
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      public? true
    end

    belongs_to :meditation, LumenViae.Rosary.Meditation do
      attribute_type :integer
      allow_nil? false
      attribute_writable? true
      attribute_public? true
      public? true
    end
  end

  identities do
    identity :unique_meditation_per_set, [:meditation_set_id, :meditation_id]
    identity :unique_order_per_set, [:meditation_set_id, :order]
  end
end
