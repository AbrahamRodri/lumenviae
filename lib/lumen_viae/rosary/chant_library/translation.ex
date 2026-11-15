defmodule LumenViae.Rosary.ChantLibrary.Translation do
  @moduledoc """
  The Chant Library's names in the language a read asked for, as the
  `translations` section of `GET /api/v2/chant-library?lang=es` serves
  them: chants and groups by `id`, for a client to lay over the English.
  See `LumenViae.Rosary.ChantLibrary.Spanish`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.ChantLibrary.Translation

  typed_struct do
    field :chants, {:array, Translation.Chant},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each chant with Spanish, by `id`, in the chants' order."

    field :groups, {:array, Translation.Group},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each group with Spanish, by `id`, in the groups' order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_library_translation
end
