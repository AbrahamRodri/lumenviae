defmodule LumenViae.Rosary.Mystery do
  @moduledoc """
  One of the mysteries of the Rosary.

  Mapped onto the existing `mysteries` table exactly as the Ecto migrations
  left it: integer ids, second-precision naive timestamps, `varchar(255)`
  where the column was an Ecto `:string`.

  Reach mysteries through `LumenViae.Rosary`; nothing outside
  `lib/lumen_viae/rosary/` names this module.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Rosary,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]

  alias LumenViae.Rosary.Categories

  graphql do
    type :mystery
  end

  postgres do
    table "mysteries"
    repo LumenViae.Repo

    # Ash would make an :integer attribute a bigint; `order` is an int4.
    migration_types name: :string, category: :string, order: :integer, days_prayed: :string
    migration_defaults inserted_at: "nil", updated_at: "nil"
    identity_index_names unique_order_in_category: "mysteries_category_order_index"

    custom_indexes do
      index [:category]
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :category, :order, :days_prayed, :description, :scripture_reference],
      update: [:name, :category, :order, :days_prayed, :description, :scripture_reference]
    ]

    read :in_prayer_order do
      description "Every mystery in the order they are prayed: by category, then by position within the category."
      prepare build(sort: [category: :asc, order: :asc])
    end

    read :by_category do
      description "One category's mysteries, in the order they are prayed."

      argument :category, :string do
        allow_nil? false
      end

      filter expr(category == ^arg(:category))
      prepare build(sort: [order: :asc])
    end
  end

  validations do
    validate one_of(:category, Categories.slugs()), message: "is invalid"
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    # One of `LumenViae.Rosary.Categories.slugs/0`. A plain string, because
    # the API serialises it as one and the iOS app matches it exactly.
    attribute :category, :string do
      allow_nil? false
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :order, :integer do
      allow_nil? false
      public? true
    end

    # A string or null, never a list: "Monday, Saturday" is what the app
    # decodes.
    attribute :days_prayed, :string do
      public? true
      constraints max_length: 255, trim?: false
    end

    attribute :description, :string do
      public? true
      constraints trim?: false
    end

    attribute :scripture_reference, :string do
      public? true
      constraints trim?: false
    end

    create_timestamp :inserted_at, type: :naive_datetime
    update_timestamp :updated_at, type: :naive_datetime
  end

  relationships do
    has_many :meditations, LumenViae.Rosary.Meditation do
      public? true
    end

    # The meditations a reader can be shown: archived ones are out of
    # circulation everywhere but the admin.
    has_many :active_meditations, LumenViae.Rosary.Meditation do
      filter expr(is_nil(archived_at))
      public? true
    end
  end

  aggregates do
    count :meditation_count, :meditations

    # A mystery whose only meditation has been archived has nothing to
    # pray, so the dashboard's health check asks this one.
    count :active_meditation_count, :active_meditations
  end

  identities do
    identity :unique_order_in_category, [:category, :order]
  end
end
