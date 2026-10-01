defmodule LumenViae.Office.Types.Hour do
  @moduledoc """
  The full text of one canonical hour on one date, section by section.
  """
  use Ash.TypedStruct

  typed_struct do
    field :date, :date, allow_nil?: false
    field :hour, :string, allow_nil?: false
    field :version, :string, allow_nil?: false
    field :language, :string, allow_nil?: false
    field :celebration, LumenViae.Office.Types.Celebration
    field :tempora, :string

    field :sections, {:array, LumenViae.Office.Types.Section},
      allow_nil?: false,
      constraints: [nil_items?: false]

    field :source, LumenViae.Office.Types.Source, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_hour
end
