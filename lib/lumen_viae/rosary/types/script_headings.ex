defmodule LumenViae.Rosary.Types.ScriptHeadings do
  @moduledoc """
  What the screen calls the prayers said on the pendant.
  """
  use Ash.TypedStruct

  typed_struct do
    field :opening, :string, allow_nil?: false, description: "Before the first decade."

    field :closing, :string, allow_nil?: false, description: "After the last."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :script_headings
end
