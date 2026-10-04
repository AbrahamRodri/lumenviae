defmodule LumenViae.Rosary.RosaryContent do
  @moduledoc """
  The Rosary's words as one document, for a client that prays offline:
  `GET /api/v2/rosary-content` and GraphQL's `rosaryContent`. The words
  are `LumenViae.Rosary.Content`'s, and the `schedule` section is
  `LumenViae.LiturgicalCalendar`'s.

  There is no table. `:current` answers with the one document there is,
  carrying a `version` that fingerprints everything it serves and the
  moment it last changed. Each section is a calculation, and Ash computes
  only the calculations a query selects: the bare request carries the
  version and the date alone, which is how a device asks whether its
  saved copy is current, and a client names the sections it wants in
  `fields[rosary_content]=` (GraphQL: the selection set).
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Prayers
  alias LumenViae.Rosary.RosaryContent.Schedule
  alias LumenViae.Rosary.RosaryContent.Script
  alias LumenViae.Rosary.Types

  graphql do
    type :rosary_content
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # The sections are not defaults: a client names those it wants in
  # fields[rosary_content]=, so asking whether its copy is current costs
  # two short fields.
  json_api do
    type "rosary_content"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Rosary's words as one document. There is only ever one."
      prepare Current
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
    calculate :prayers, {:array, Types.RosaryPrayer}, Prayers do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The twelve prayers of the Rosary and the Seven Sorrows chaplet, in the order they are said, in English and Latin."
    end

    calculate :schedule, Types.RosarySchedule, Schedule do
      allow_nil? false
      public? true

      description "Which mysteries a day calls for, on both weekly schedules, as rules to apply offline: each weekday's set, Sunday's by season, every Lent and Advent from last year to three years ahead, the home grid's order and the days each set is prayed in words. The day is the device's calendar day, turning at midnight, not the prayer day that turns at four in the morning."
    end

    calculate :script, Types.ScriptTemplates, Script do
      allow_nil? false
      public? true

      description "The order a Rosary is said in, as templates a client expands offline: the Rosary's and the chaplet's steps, the optional prayers after the Rosary and the strand's beads. GET /api/v2/rosary-script expands them."
    end
  end
end
