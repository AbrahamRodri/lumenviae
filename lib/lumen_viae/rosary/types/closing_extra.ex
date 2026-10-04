defmodule LumenViae.Rosary.Types.ClosingExtra do
  @moduledoc """
  One of the optional prayers said after a Rosary's closing prayer and
  before its last Sign of the Cross, chosen in the app's settings.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "`holy_father`, `memorare` or `st_michael`: what `extras` names in `GET /api/v2/rosary-script`."

    field :title, :string, allow_nil?: false, description: "What the setting is called."

    field :short_title, :string,
      allow_nil?: false,
      description: "The name where three share a row."

    field :detail, :string,
      allow_nil?: false,
      description: "What the setting adds, said as what is prayed."

    field :steps, {:array, Types.ScriptTemplateStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The prayers said."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :closing_extra
end
