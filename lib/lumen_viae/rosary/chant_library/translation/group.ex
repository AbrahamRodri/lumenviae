defmodule LumenViae.Rosary.ChantLibrary.Translation.Group do
  @moduledoc "One chant group's title, note and parts in another language. See `LumenViae.Rosary.ChantLibrary.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The group's id, the same as in `groups`."
    field :title, :string, allow_nil?: false, description: "Its title in this language."

    field :note, :string,
      description: "Its note in this language; null where the English has none."

    field :parts, {:array, LumenViae.Rosary.ChantLibrary.Translation.Part},
      allow_nil?: false,
      default: [],
      constraints: [nil_items?: false],
      description:
        "Its parts' headings and notes, in the same order as the group's `parts`; empty where its parts have no words."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_group_translation
end
