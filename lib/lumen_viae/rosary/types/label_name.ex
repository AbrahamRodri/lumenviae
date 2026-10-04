defmodule LumenViae.Rosary.Types.LabelName do
  @moduledoc """
  A stored label and what the app calls it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The label as a set stores and serves it: raw, case-sensitive."

    field :name, :string,
      allow_nil?: false,
      description:
        "What a reader sees. Equal to `id` where the app does not reword it (`Considerations` reads Reflections, `Contemplative` Inside the Scene, `Scriptural` Gospel)."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :label_name
end
