defmodule LumenViae.Rosary.ChantLibrary.Translation.Part do
  @moduledoc "One part of a chant group in another language, by position. See `LumenViae.Rosary.ChantLibrary.Translation.Group`."
  use Ash.TypedStruct

  typed_struct do
    field :title, :string,
      description: "The part's heading in this language; null where the English has none."

    field :note, :string,
      description: "The part's note in this language; null where the English has none."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_group_part_translation
end
