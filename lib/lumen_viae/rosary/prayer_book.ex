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
  # The one read takes an optional `lang`, so Ash's warning that a primary
  # read should take no arguments is off: nothing loads this resource
  # through a relationship, which is what that warning protects.
  use Ash.Resource,
    primary_read_warning?: false,
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

      argument :lang, :string do
        description "The language of `translations`: `es` fills it with every prayer the book has in Spanish. Missing, `en` or a language not served: the document as it always was, and `translations` empty."
      end

      prepare LumenViae.Rosary.PrayerBook.Current
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

    # The language the read asked for (`Content.language/1`), for the
    # `translations` section. Not served itself.
    attribute :lang, :string do
      allow_nil? false
      default "en"
      public? false
    end
  end

  calculations do
    calculate :prayers,
              {:array, Types.BookPrayer},
              {Library.Section, document: :prayer_book, section: "prayers"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every prayer the book prints, each once, the Rosary's and the consecration's included. A client keeps a prayer no chapter names: an order of prayer may."
    end

    calculate :chapters,
              {:array, Types.PrayerBookChapter},
              {Library.Section, document: :prayer_book, section: "chapters"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The book's chapters in order, each with its sub-headings and the prayers under them."
    end

    calculate :orders,
              {:array, Types.PrayerOrder},
              {Library.Section, document: :prayer_book, section: "orders"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The orders of prayer, a few prayers said together (Morning Prayers, Before Mass), in the app's order: the three of the day first, then those for an occasion."
    end

    calculate :translations,
              {:array, LumenViae.Rosary.PrayerBook.Translation},
              LumenViae.Rosary.PrayerBook.Translations do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "With `lang=es`, every prayer the book prints, by id, in book order: its title and words in Spanish, from Church sources where they exist. `ai_translated` marks the team's own translation. A prayer not listed has no Spanish; show its English. Empty in English."
    end

    calculate :marian_antiphons,
              {:array, Types.MarianAntiphon},
              {Library.Section, document: :prayer_book, section: "marian_antiphons"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The four songs to Mary through the year, in the order their seasons begin from Advent. An order that closes with the season's song ends on the one whose season holds the day."
    end

    calculate :novenas,
              {:array, Types.Novena},
              {Library.Section, document: :prayer_book, section: "novenas"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The novenas, days of prayer said one a day. Each is also one of `prayers`, its twin (`prayer_id`), holding every day as plain text: show the novena in the twin's place, not both. Served only when named in `fields[prayer_book]`."
    end
  end
end
