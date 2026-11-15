defmodule LumenViae.Rosary.ChantLibrary.Translation.Chant do
  @moduledoc "One chant's names in another language. See `LumenViae.Rosary.ChantLibrary.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The chant's id, the same as in `chants`."

    field :title, :string,
      allow_nil?: false,
      description:
        "Its name in this language, in place of `english_title`. May be the Latin itself (Salve Regina) where that is the name in use."

    field :setting, :string,
      description:
        "Its setting in this language, in place of `setting`: null exactly when `setting` is."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_translation
end
