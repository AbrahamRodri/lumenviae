defmodule LumenViae.Rosary.SpiritualReading do
  @moduledoc """
  The Spiritual Reading shelf's catalogue as one document, for a client
  that reads it offline: `GET /api/v2/spiritual-reading` and GraphQL's
  `spiritualReading`. Five public-domain books, each with its Project
  Gutenberg and LibriVox numbers and the rules that cut that edition into
  chapters and line its recording up with them, as the iOS app holds them
  (`Data/LibraryCatalog.swift`). The words are `LumenViae.Rosary.Library`'s,
  from `priv/library/spiritual_reading.json`.

  The books themselves are not served: a device fetches the text from
  Gutenberg and streams the recording from LibriVox. Serving the rules
  means a book that changes shape is fixed with a deploy, not an app
  release.

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
    type :spiritual_reading
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # As with the Prayer Book, the sections are not defaults: a client names
  # those it wants in fields[spiritual_reading]=.
  json_api do
    type "spiritual_reading"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Spiritual Reading catalogue as one document. There is only ever one."
      prepare {Library.Current, document: :spiritual_reading}
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
    calculate :books,
              {:array, Types.SpiritualBook},
              {Library.Section, document: :spiritual_reading, section: "books"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The shelf's books in order, each with its sources and the rules for its edition."
    end
  end
end
