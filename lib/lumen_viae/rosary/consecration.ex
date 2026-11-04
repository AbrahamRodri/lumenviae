defmodule LumenViae.Rosary.Consecration do
  @moduledoc """
  The 33-day Consecration to Jesus through Mary as one document, for a
  client that prays it offline: `GET /api/v2/consecration` and GraphQL's
  `consecration`. The words are `LumenViae.Rosary.Library`'s, from
  `priv/library/consecration.json`, which holds what the iOS app bundles.

  It is served as the Prayer Book is: no table, one document with a
  `version` and the moment it last changed, and each section a
  calculation computed only when a query selects it. The bare request is
  how a device asks whether its saved copy is current; a client names the
  sections it wants in `fields[consecration]=` (GraphQL: the selection
  set). Where a reader is in the 33 days, and their journal, stay on the
  device.
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
    type :consecration
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # As with the Prayer Book, the sections are not defaults: a client names
  # those it wants in fields[consecration]=.
  json_api do
    type "consecration"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The 33-day Consecration as one document. There is only ever one."

      argument :lang, :string do
        description "The language of `translations`: `es` fills it with every part of the Consecration that has Spanish. Missing, `en` or a language not served: the document as it always was, and `translations` empty."
      end

      prepare LumenViae.Rosary.Consecration.Current
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
    calculate :phases,
              {:array, Types.ConsecrationPhase},
              {Library.Section, document: :consecration, section: "phases"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The phases in order, from the twelve preparatory days to Consecration Day, each with its days' span and the prayers said on each of them."
    end

    calculate :days,
              {:array, Types.ConsecrationDay},
              {Library.Section, document: :consecration, section: "days"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every day in order, 1 to 34, each with its theme, its readings and its journal prompt. Day 34 is Consecration Day."
    end

    calculate :prayers,
              {:array, Types.ConsecrationPrayer},
              {Library.Section, document: :consecration, section: "prayers"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every prayer a phase names, each once, in the Consecration's own words."
    end

    calculate :feasts,
              {:array, Types.MarianFeast},
              {Library.Section, document: :consecration, section: "feasts"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The feasts of Mary a Consecration may end on, in calendar order. Day 1 is 33 days before the feast."
    end

    calculate :translations,
              LumenViae.Rosary.Consecration.Translation,
              LumenViae.Rosary.Consecration.Translations do
      allow_nil? false
      public? true

      description "With `lang=es`, the Consecration's words in Spanish, keyed as the English sections key them: phases and prayers by `id`, days by `number` and their readings by `order`, feasts by `id`. A part not listed has no Spanish; show its English. `ai_translated` marks the team's own translation. In English, four empty lists."
    end
  end
end
