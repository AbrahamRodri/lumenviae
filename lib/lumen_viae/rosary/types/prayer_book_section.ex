defmodule LumenViae.Rosary.Types.PrayerBookSection do
  @moduledoc """
  One sub-heading of a Prayer Book chapter and the prayers under it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false, description: "The sub-heading."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The prayers under it, in order, each one of the document's prayers. A prayer may stand under two sub-headings."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_book_section
end
