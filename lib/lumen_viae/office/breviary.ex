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
  """
  use Ash.Resource,
    domain: LumenViae.Office,
    extensions: [AshGraphql.Resource]

  alias LumenViae.Office.Breviary.Read
  alias LumenViae.Office.Types

  graphql do
    generate_object? false
  end

  actions do
    action :hour, Types.Hour do
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
      description "All eight hours of one date, Matins to Compline, in that order."
      constraints nil_items?: false
      argument :date, :date, allow_nil?: false
      argument :version, :string, description: "A version slug; see officeVocabulary."
      argument :language, :string, description: "A language slug; see officeVocabulary."
      run {Read, kind: :hours}
    end

    action :day, Types.Day do
      description "One day's place in the calendar: its celebration, season and rubric note."
      argument :date, :date, allow_nil?: false
      argument :version, :string, description: "A version slug; see officeVocabulary."
      run {Read, kind: :day}
    end

    action :calendar, Types.Calendar do
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
end
