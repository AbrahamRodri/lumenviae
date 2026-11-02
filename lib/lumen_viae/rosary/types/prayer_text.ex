defmodule LumenViae.Rosary.Types.PrayerText do
  @moduledoc """
  A prayer's words in English and Latin, each a list of lines. The two
  lists are the same length: line n of one is line n of the other.
  """
  use Ash.TypedStruct

  typed_struct do
    field :en, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "In English, line by line."

    field :la, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "In Latin, line by line."

    field :es, {:array, :string},
      constraints: [nil_items?: false],
      description:
        "In Spanish, line by line. Only with `lang=es`, and then always present: the English where there is no Spanish yet. Its lines need not pair with the Latin."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_text
end
