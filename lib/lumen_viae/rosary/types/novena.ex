defmodule LumenViae.Rosary.Types.Novena do
  @moduledoc """
  A novena: days of prayer said one a day, as `GET /api/v2/prayer-book`
  serves it in `novenas`. Each novena is also one of the book's prayers,
  its twin (`prayer_id`), holding every day's words as plain text for a
  client that does not know novenas; an app that shows the novena shows it
  instead of the twin. A day names the book's prayers or holds its own
  words, and every word a day holds is in the twin, word for word.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "The novena's id (`undoer_of_knots`). Stable forever: a device stores it with a person's progress."

    field :title, :string,
      allow_nil?: false,
      description: "Its name (`Our Lady, Undoer of Knots`)."

    field :list_title, :string, description: "A shorter name for a list, or null to use `title`."
    field :latin_title, :string, description: "Its Latin name, or null."

    field :detail, :string,
      allow_nil?: false,
      description: "What it is, in one plain sentence, for its card."

    field :note, :string,
      description: "Where the devotion comes from and how it is prayed, or null."

    field :origin, :string,
      description:
        "Where its words come from, as the book credits a prayer (`Composed for Lumen Viae from ...`), or null."

    field :prayer_id, :string,
      allow_nil?: false,
      description:
        "Its twin, one of the document's prayers: every day as plain text. Show the novena in its place, not both."

    field :chapter_id, :string,
      allow_nil?: false,
      description: "The chapter it is shown in, one of the document's chapters."

    field :length, :integer,
      allow_nil?: false,
      constraints: [min: 1],
      description:
        "How many days it runs, the number of `days`. Usually 9; never assume it (the St. Andrew novena is 25)."

    field :feast, Types.ChantFeastRule,
      description:
        "The feast it ends on, in the chant library's rule shape: day 1 is `length` days before it, so the last day is the eve. Null when it may be begun on any day."

    field :painting, :string,
      description: "Its painting, by the name the apps bundle it under, or null."

    field :art, Types.NovenaArt,
      description:
        "Its painting as a public file, for an app that does not bundle it, or null until there is one."

    field :chant_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Chants that suit it, each one of the chant library's chants (`GET /api/v2/chant-library`). Empty when none."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Other names it is looked for by, beside its titles. Empty when none."

    field :days, {:array, Types.NovenaDay},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Its days in order, numbered 1 to `length`."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena
end
