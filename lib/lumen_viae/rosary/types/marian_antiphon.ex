defmodule LumenViae.Rosary.Types.MarianAntiphon do
  @moduledoc """
  One of the four songs to Mary sung at the close of the day, each through
  its own part of the year, and so the last words of Night Prayers.
  """
  use Ash.TypedStruct

  typed_struct do
    field :prayer_id, :string,
      allow_nil?: false,
      description: "The song, one of the document's prayers (`hail_holy_queen`)."

    field :title, :string, allow_nil?: false, description: "Its English name."
    field :latin_title, :string, allow_nil?: false, description: "Its Latin name."

    field :season, :string,
      allow_nil?: false,
      description: "When it is sung, as the app prints it (`Pentecost to Advent`)."

    field :begins, :string,
      allow_nil?: false,
      constraints: [match: ~r/\A(advent_eve|february_2|easter|pentecost_saturday)\z/],
      description:
        "The day its season begins: `advent_eve` (the day before the First Sunday of Advent), `february_2`, `easter` (Easter Sunday) or `pentecost_saturday` (the Saturday after Pentecost). Each is sung until the next one begins."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :marian_antiphon
end
