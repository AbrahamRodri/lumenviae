defmodule LumenViae.Rosary.Types.PrayerOrder do
  @moduledoc """
  An order of prayer: a few of the book's prayers said together, one after
  another (Morning Prayers, Before Mass, After Confession), as
  `GET /api/v2/prayer-book` serves it. The words are the prayers'; an order
  only names them.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The order's id (`morning`). Stable forever: a device stores it."

    field :title, :string, allow_nil?: false, description: "Its name (`Morning Prayers`)."
    field :latin_title, :string, allow_nil?: false, description: "Its Latin name."

    field :occasion, :string,
      allow_nil?: false,
      description: "When it is prayed, as a short kicker (`On waking`)."

    field :detail, :string, allow_nil?: false, description: "What it is, in one plain sentence."

    field :chapter_id, :string,
      description: "The chapter it is shown in, one of the document's chapters, or null."

    field :search_words, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Other names it is looked for by, beside its titles. Empty when none."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Its prayers in the order they are said, each one of the document's prayers. Outside Eastertide, and before the closing song to Mary."

    field :in_eastertide, Types.PrayerOrderVariant,
      description:
        "What the order becomes from Easter Sunday to the Saturday after Pentecost (the Angelus gives way to Queen of Heaven), or null when it does not change."

    field :closes_with_marian_antiphon, :boolean,
      allow_nil?: false,
      description:
        "Whether the order ends on the season's song to Mary, one of `marian_antiphons` (Night Prayers do)."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_order
end
