defmodule LumenViae.Office.Types.Vocabulary do
  @moduledoc """
  What a client needs before asking for anything else: the version, hour
  and language slugs the Office accepts, and the defaults it falls back to.
  """
  use Ash.TypedStruct

  typed_struct do
    field :versions, {:array, LumenViae.Office.Types.Choice},
      allow_nil?: false,
      constraints: [nil_items?: false]

    field :hours, {:array, LumenViae.Office.Types.Choice},
      allow_nil?: false,
      constraints: [nil_items?: false]

    field :languages, {:array, LumenViae.Office.Types.Choice},
      allow_nil?: false,
      constraints: [nil_items?: false]

    field :default_version, :string, allow_nil?: false
    field :default_language, :string, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :office_vocabulary
end
