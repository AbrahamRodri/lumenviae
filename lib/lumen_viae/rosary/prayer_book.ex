defmodule LumenViae.Rosary.PrayerBook do
  @moduledoc """
  The Prayer Book's words as one document, for a client that prays
  offline: `GET /api/v2/prayer-book` and GraphQL's `prayerBook`. The words
  are `LumenViae.Rosary.Library`'s, from `priv/library/prayer_book.json`.

  There is no table. `:current` answers with the one document there is,
  carrying a `version` that fingerprints everything it serves and the
  moment it last changed. Each section is a calculation, and Ash computes
  only those a query selects: the bare request carries the version and
  the date alone, which is how a device asks whether its saved copy is
  current, and a client names the sections it wants in
  `fields[prayer_book]=` (GraphQL: the selection set).
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  graphql do
    type :prayer_book
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # The sections are not defaults: a client names those it wants in
  # fields[prayer_book]=, so asking whether its copy is current costs two
  # short fields.
  json_api do
    type "prayer_book"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Prayer Book's words as one document. There is only ever one."
      prepare {Library.Current, document: :prayer_book}
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
    calculate :prayers,
              {:array, Types.BookPrayer},
              {Library.Section,
               document: :prayer_book, section: "prayers", type: Types.BookPrayer} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every prayer the book prints, each once, the Rosary's and the consecration's included. A client keeps a prayer no chapter names: an order of prayer may."
    end

    calculate :chapters,
              {:array, Types.PrayerBookChapter},
              {Library.Section,
               document: :prayer_book, section: "chapters", type: Types.PrayerBookChapter} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The book's chapters in order, each with its sub-headings and the prayers under them."
    end
  end
end
