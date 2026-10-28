defmodule LumenViae.Rosary.ChantLibrary do
  @moduledoc """
  The Chant Library as one document: `GET /api/v2/chant-library` and
  GraphQL's `chantLibrary`. Every chant's titles, timed lines, and the
  public URLs of its recording and sheet music, from
  `priv/library/chant_library.json` (`LumenViae.Rosary.Library`).

  There is no table. `:current` answers with the one document there is,
  carrying a `version` that fingerprints everything it serves and the
  moment it last changed. Each section is a calculation, and Ash computes
  only those a query selects: the bare request carries the version and
  the date alone, and a client names the sections it wants in
  `fields[chant_library]=` (GraphQL: the selection set).
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.Types

  graphql do
    type :chant_library
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # The sections are not defaults: a client names those it wants in
  # fields[chant_library]=, so asking whether its copy is current costs
  # two short fields.
  json_api do
    type "chant_library"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Chant Library as one document. There is only ever one."
      prepare {Library.Current, document: :chant_library}
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

      description "Fingerprints everything the document serves, the chant files' URLs included: a device whose copy has the same version holds the current library. Compare it; do not parse it."
    end

    attribute :updated_at, :utc_datetime do
      allow_nil? false
      public? true
      description "When the content last changed."
    end
  end

  calculations do
    calculate :groups,
              {:array, Types.ChantGroup},
              {Library.Section, document: :chant_library, section: "groups"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The library's groups in the Parish Book of Chant's order, each naming its chants."
    end

    calculate :chants,
              {:array, Types.Chant},
              {Library.Section, document: :chant_library, section: "chants"} do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "Every chant, in the catalog's order: a client takes the first chant listed for a prayer."
    end
  end
end
