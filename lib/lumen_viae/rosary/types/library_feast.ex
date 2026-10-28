defmodule LumenViae.Rosary.Types.LibraryFeast do
  @moduledoc """
  A feast kept on a fixed day of the year, as the Marian Library and St.
  Carlo's page name it: its date, whether the 1962 Missal has its Mass,
  and, on the Marian Library's calendar, its painting and its reading.
  """
  use Ash.TypedStruct

  typed_struct do
    field :month, :integer, allow_nil?: false, description: "Its month, 1 to 12."
    field :day, :integer, allow_nil?: false, description: "Its day of the month."
    field :name, :string, allow_nil?: false, description: "Its name (`Our Lady of Lourdes`)."

    field :in_missal, :boolean,
      allow_nil?: false,
      description:
        "Whether it is on the universal 1962 calendar, so the Missal has its Mass. False for a later or local feast, which opens no Mass."

    field :kept_by, :string,
      description:
        "The place or people it is kept by when it is not universal (`the Americas`), or null."

    field :painting, :string,
      description:
        "The painting it is shown in, by the apps' painting name (`mary_immaculate_conception`), or null where none is set."

    field :reading_id, :string,
      description: "The id of the reading about it on the same document's shelves, or null."

    field :reading_name, :string,
      description:
        "The short name its reading goes by when that is not the feast's own (`Lepanto`), or null."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :library_feast
end
