defmodule LumenViae.Rosary.Types.NovenaPart do
  @moduledoc """
  One part of a novena's day: one of the book's prayers, named by
  `prayer_id`; the day's own words in `text`; or, for a `rosary` part, the
  decades of the day's mysteries prayed there. A prayer or words may be
  said `times` times, and a part may name a book prayer said instead of it
  (`or_prayer_id`).
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description:
        "What the part is: `opening`, `meditation`, `prayer`, `novena_prayer`, `invocation`, `saying`, `practice`, `closing` or `rosary`, and more may come. Show a kind you do not know as plain text."

    field :prayer_id, :string,
      description: "One of the document's prayers, said here, or null when the part holds `text`."

    field :or_prayer_id, :string,
      description:
        "One of the document's prayers that may be said instead of this part (the Litany of Loreto in place of the Tota pulchra versicles), or null. A client that ignores it shows the part, which is always right."

    field :times, :integer,
      constraints: [min: 1],
      description:
        "How many times the part is said, the named prayer or the day's own words (nine Hail Marys; the St. Andrew prayer 15 times a day), or null for once."

    field :id, :string,
      description:
        "The words' id (`undoer_of_knots_d1_prayer`), stable for a device's saved place, or null when the part names a prayer. Words said every day (an invocation, the closing prayer) keep one id on every day, so a saved place is the day's number and the part's id together, never the id alone."

    field :title, :string,
      description:
        "The words' heading (`Genesis 3:15`), or null: a part that names a prayer, and a short invocation or saying, has none."

    field :text, :string,
      description:
        "The day's own words, written as a prayer's `english` is, or null when the part names a prayer. They also stand in the twin prayer, word for word."

    field :source, :string, description: "Where the words come from (`Douay-Rheims`), or null."

    field :decades, {:array, :integer},
      constraints: [nil_items?: false],
      description:
        "For a `rosary` part: the decades of the day's mysteries prayed here, 1 to 5 in order (`[1, 2, 3]`, then `[4, 5]` after a meditation). Null for every other part."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena_part
end
