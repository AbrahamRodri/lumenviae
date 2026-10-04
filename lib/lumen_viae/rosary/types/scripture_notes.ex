defmodule LumenViae.Rosary.Types.ScriptureNotes do
  @moduledoc """
  The words that frame the mysteries in Scripture.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :intro, :string, allow_nil?: false, description: "The opening line."

    field :before_each_decade, Types.NumberedPoints,
      allow_nil?: false,
      description: "What to do with a mystery's verse before its decade."

    field :fruit_note, :string, allow_nil?: false, description: "What a mystery's fruit is."

    field :sorrows_graces_note, :string,
      allow_nil?: false,
      description:
        "The line over the seven graces promised to those devoted to Our Lady's sorrows."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :scripture_notes
end
