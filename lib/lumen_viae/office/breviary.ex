defmodule LumenViae.Office.Breviary do
  @moduledoc """
  The Office as GraphQL sees it: one resource with no table and no data
  layer, whose generic actions read the breviary.

  Each action is a thin adapter over the domain's own functions
  (`LumenViae.Office.fetch_hour/3` and its siblings), which the REST
  controller calls too. Validation, the engine, the parser and the cache
  are shared, so the two APIs cannot disagree about what a date or a
  version means; only the shape of the answer differs.

  A date is typed here as a `Date`. Hours, versions and languages stay
  strings, spelled exactly as the REST API spells them ("laudes",
  "rubrics-1960"), and are checked by the domain with the same messages.
  A GraphQL enum would have been tidier, but AshGraphql upper-cases enum
  values, and one word spelled two ways across two APIs is worse than an
  untyped argument whose valid values `officeVocabulary` lists.

  The reads that can fail are nullable at the root (`allow_nil? true`).
  A GraphQL error in a non-null root field nulls the whole response, so a
  document asking for today's and tomorrow's hours would lose today's to
  an engine timeout on tomorrow's. Nullable, the failing field is null with
  its error beside it and its siblings keep their data.
  """
  use Ash.Resource,
    domain: LumenViae.Office,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  alias LumenViae.Office.Breviary.Read
  alias LumenViae.Office.Types

  graphql do
    generate_object? false
  end

  actions do
    action :hour, Types.Hour do
      allow_nil? true
      description "The full text of one canonical hour on one date."
      argument :date, :date, allow_nil?: false

      argument :hour, :string,
        allow_nil?: false,
        description: "An hour slug, such as laudes; see officeVocabulary."

      argument :version, :string, description: "A version slug; see officeVocabulary."
      argument :language, :string, description: "A language slug; see officeVocabulary."
      run {Read, kind: :hour}
    end

    action :hours, {:array, Types.Hour} do
      allow_nil? true
      description "All eight hours of one date, Matins to Compline, in that order."
      constraints nil_items?: false
      argument :date, :date, allow_nil?: false
      argument :version, :string, description: "A version slug; see officeVocabulary."
      argument :language, :string, description: "A language slug; see officeVocabulary."
      run {Read, kind: :hours}
    end

    action :day, Types.Day do
      allow_nil? true
      description "One day's place in the calendar: its celebration, season and rubric note."
      argument :date, :date, allow_nil?: false
      argument :version, :string, description: "A version slug; see officeVocabulary."
      run {Read, kind: :day}
    end

    action :calendar, Types.Calendar do
      allow_nil? true
      description "One month of the liturgical calendar, its days in date order."
      argument :year, :integer, allow_nil?: false
      argument :month, :integer, allow_nil?: false
      argument :version, :string, description: "A version slug; see officeVocabulary."
      run {Read, kind: :calendar}
    end

    action :vocabulary, Types.Vocabulary do
      description "The version, hour and language slugs the Office accepts, and its defaults."
      run {Read, kind: :vocabulary}
    end
  end

  # The Office is public text: every action is open to anyone, as the REST
  # endpoints that call the same functions are.
  policies do
    policy action_type(:action) do
      authorize_if always()
    end
  end
end
