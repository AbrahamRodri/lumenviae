defmodule LumenViae.Rosary.Consecration.Translation do
  @moduledoc """
  The Consecration in the language a read asked for, as the `translations`
  section of `GET /api/v2/consecration?lang=es` serves it: each part keyed
  as the English sections key it, for a client to lay over the English.
  See `LumenViae.Rosary.Consecration.Spanish`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Consecration.Translation

  typed_struct do
    field :phases, {:array, Translation.Phase},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each phase with Spanish, by `id`, in the phases' order."

    field :days, {:array, Translation.Day},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each day with Spanish, by `number`, in order."

    field :prayers, {:array, Translation.Prayer},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each prayer with Spanish, by `id`, in the prayers' order."

    field :feasts, {:array, Translation.Feast},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Each feast with Spanish, by `id`, in calendar order."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_translation
end
