defmodule LumenViae.Rosary.TrueDevotion do
  @moduledoc """
  St. Louis de Montfort's True Devotion to the Blessed Virgin, the whole
  book, as one document for a client that reads it offline:
  `GET /api/v2/true-devotion` and GraphQL's `trueDevotion`. The words are
  `LumenViae.Rosary.Library`'s, from `priv/library/true_devotion.json`,
  which holds the book the iOS app bundles (Fr. Faber's 1862
  translation, public domain), and its summary page's teaching shelf and
  ejaculatory prayers.

  It is served as the Prayer Book is: no table, one document with a
  `version` and the moment it last changed, and each section a
  calculation computed only when a query selects it. The bare request is
  how a device asks whether its saved copy is current; a client names the
  sections it wants in `fields[true_devotion]=` (GraphQL: the selection
  set). Where a reader is in the book, and what they marked, stay on the
  device.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  graphql do
    type :true_devotion
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # As with the Prayer Book, the sections are not defaults: a client names
  # those it wants in fields[true_devotion]=.
  json_api do
    type "true_devotion"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "True Devotion, the whole book, as one document. There is only ever one."
      prepare {Library.Current, document: :true_devotion}
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
    calculate :about,
              Types.TrueDevotionAbout,
              {Library.Section, document: :true_devotion, section: "about"} do
      allow_nil? false
      public? true

      description "The book's title, author and translator, and the edition its text is taken from."
    end

    calculate :parts,
              {:array, Types.TrueDevotionPart},
              {Library.Section, document: :true_devotion, section: "parts"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The book's two parts in order. A chapter names its part by number; the Introduction is in neither."
    end

    calculate :chapters,
              {:array, Types.TrueDevotionChapter},
              {Library.Section, document: :true_devotion, section: "chapters"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every chapter in reading order, from the Introduction to the Act of Consecration, each with its paragraphs."
    end

    calculate :teaching,
              Types.LibraryShelf,
              {Library.Section, document: :true_devotion, section: "teaching"} do
      allow_nil? false
      public? true

      description "The summary page's shelf of short readings on the devotion (`true_devotion_teaching`): its foundations, principles, marks, false devotions, benefits and spirit."
    end

    calculate :ejaculatory_prayers,
              {:array, Types.TrueDevotionPrayer},
              {Library.Section, document: :true_devotion, section: "ejaculatory_prayers"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The summary page's ejaculatory prayers from the book, each in English and Latin."
    end
  end
end
