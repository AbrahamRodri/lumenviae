defmodule LumenViae.Rosary.CarloAcutis do
  @moduledoc """
  St. Carlo Acutis's page as one document, for a client that reads it
  offline: `GET /api/v2/carlo-acutis` and GraphQL's `carloAcutis`. His
  life in five readings and his four devotions, his timeline, his rule of
  life, his sayings and a prayer for his intercession, as the iOS app
  holds them (`Data/CarloAcutisData.swift`). The words are
  `LumenViae.Rosary.Library`'s, from `priv/library/carlo_acutis.json`.

  Served as the Prayer Book is: no table, one document with a `version`
  and the moment it last changed, each section a calculation computed only
  when a query selects it. His photo is the app's own, bundled; this
  document carries none.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  graphql do
    type :carlo_acutis
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # As with the Prayer Book, the sections are not defaults: a client names
  # those it wants in fields[carlo_acutis]=.
  json_api do
    type "carlo_acutis"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "St. Carlo Acutis's page as one document. There is only ever one."
      prepare {Library.Current, document: :carlo_acutis}
    end
  end

  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action(:current) do
      authorize_if always()
    end
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      description "Always `current`: there is one document."
    end

    attribute :version, :string do
      allow_nil? false
      public? true

      description "Fingerprints everything the document serves: a device whose copy has the same version holds every current word. Compare it; do not parse it."
    end

    attribute :updated_at, :utc_datetime do
      allow_nil? false
      public? true
      description "When the content last changed."
    end
  end

  calculations do
    calculate :feast,
              Types.LibraryFeast,
              {Library.Section, document: :carlo_acutis, section: "feast"} do
      allow_nil? false
      public? true

      description "His feast, 12 October, the day he died. Not on the 1962 calendar, so it opens no Mass."
    end

    calculate :shelves,
              {:array, Types.LibraryShelf},
              {Library.Section, document: :carlo_acutis, section: "shelves"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "His life (`carlo_life`) and his devotions (`carlo_devotions`), each a shelf of readings."
    end

    calculate :timeline,
              {:array, Types.CarloMoment},
              {Library.Section, document: :carlo_acutis, section: "timeline"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "His life as a timeline, in order, each moment opening its reading."
    end

    calculate :rule,
              {:array, Types.CarloHabit},
              {Library.Section, document: :carlo_acutis, section: "rule"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "His rule of life: what he did every day or every week, each with its reading and the act that does it today."
    end

    calculate :sayings,
              {:array, :string},
              {Library.Section, document: :carlo_acutis, section: "sayings"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "His sayings, as his mother and biographers handed them on. One a day, the same all day: the day of the year (1 to 366) modulo the count."
    end

    calculate :prayer,
              :string,
              {Library.Section, document: :carlo_acutis, section: "prayer"} do
      allow_nil? false
      public? true

      description "A prayer for his intercession, in the Prayer Book's grammar."
    end
  end
end
