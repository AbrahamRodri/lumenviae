defmodule LumenViae.Rosary.MarianLibrary do
  @moduledoc """
  The Marian Library as one document, for a client that reads it offline:
  `GET /api/v2/marian-library` and GraphQL's `marianLibrary`. Six shelves
  of short readings on Our Lady (the dogmas, Scripture, the apparitions,
  the saints, the Rosary's history, her titles) and the Marian feasts of
  the 1962 calendar, as the iOS app holds them
  (`Data/MarianLibraryData.swift`). The words are
  `LumenViae.Rosary.Library`'s, from `priv/library/marian_library.json`.

  Served as the Prayer Book is: no table, one document with a `version`
  and the moment it last changed, each section a calculation computed only
  when a query selects it.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  graphql do
    type :marian_library
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # As with the Prayer Book, the sections are not defaults: a client names
  # those it wants in fields[marian_library]=.
  json_api do
    type "marian_library"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Marian Library as one document. There is only ever one."
      prepare {Library.Current, document: :marian_library}
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
    calculate :feasts,
              {:array, Types.LibraryFeast},
              {Library.Section, document: :marian_library, section: "feasts"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The feasts of Our Lady on the universal 1962 calendar in the order of the year, and Guadalupe, kept in the Americas; each with its painting and, where the library has one, its reading."
    end

    calculate :shelves,
              {:array, Types.LibraryShelf},
              {Library.Section, document: :marian_library, section: "shelves"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The six shelves in order, each with its readings."
    end
  end
end
