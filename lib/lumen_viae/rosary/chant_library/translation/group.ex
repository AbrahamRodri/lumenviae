defmodule LumenViae.Rosary.ChantLibrary.Translation.Group do
  @moduledoc "One chant group's title in another language. See `LumenViae.Rosary.ChantLibrary.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The group's id, the same as in `groups`."
    field :title, :string, allow_nil?: false, description: "Its title in this language."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_group_translation
end
