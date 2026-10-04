defmodule LumenViae.Rosary.RosaryScript do
  @moduledoc """
  One Rosary's script, expanded: every step from the Sign of the Cross to
  the last Amen, for `GET /api/v2/rosary-script` and GraphQL's
  `rosaryScript`. It is `LumenViae.Rosary.PrayerAudio.script/3`, the
  expansion the website prays aloud with, and the reference a client's own
  expansion of the `script` templates
  (`LumenViae.Rosary.RosaryContent`) is held to.

  There is no table. `:expand` answers with one record for the Rosary its
  arguments describe. Lists travel as comma-separated strings, which every
  client spells the same way in a query string.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.RosaryScript.Expand
  alias LumenViae.Rosary.Types

  graphql do
    type :rosary_script
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  json_api do
    type "rosary_script"
    derive_filter? false
    derive_sort? false
  end

  actions do
    # AshAdmin's. A script needs a category, so the primary read, which
    # takes none, answers with nothing.
    read :read do
      primary? true
    end

    read :expand do
      get? true

      description "One Rosary's script, every step in order: a category's mysteries in a style, with any optional prayers after it."

      argument :category, :string do
        allow_nil? false

        description "The mysteries prayed: joyful, sorrowful, glorious, luminous or seven_sorrows (the chaplet)."
      end

      argument :style, :string do
        description "meditation (the default): the set's meditation after each announcement. scriptural: a verse before every Hail Mary. plain: the Rosary Said Aloud, the prayers alone."
      end

      argument :extras, :string do
        description "The optional prayers after the Rosary, comma-separated, any of holy_father, memorare, st_michael. Said in that order whatever order they are given in; the chaplet takes none."
      end

      argument :orders, :string do
        description "The mysteries' orders in prayer order, comma-separated (3,4,5), for a set whose meditations do not run from the first. Every mystery of the category when absent."
      end

      prepare Expand
    end
  end

  # The v2 route's and GraphQL's rosaryScript. The primary read is only
  # AshAdmin's.
  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action(:expand) do
      authorize_if always()
    end
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true

      description "The Rosary described: its category, style, extras and orders, separated by colons."
    end

    attribute :category, :string do
      allow_nil? false
      public? true
    end

    attribute :style, :string do
      allow_nil? false
      public? true
    end

    attribute :extras, {:array, :string} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "The optional prayers said, in the order they are said."
    end

    attribute :orders, {:array, :integer} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "The mysteries' orders, one per decade, in prayer order."
    end

    attribute :steps, {:array, Types.ScriptStep} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "Every step, in the order it is said."
    end
  end
end
