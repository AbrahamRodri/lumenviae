defmodule LumenViae.Rosary.Types.CarloHabit do
  @moduledoc """
  One habit of St. Carlo's rule of life: what he did, how often, the
  reading that tells of it, and the act that does it with him today.
  """
  use Ash.TypedStruct

  typed_struct do
    field :icon, :string,
      allow_nil?: false,
      description: "The iOS app's glyph name for it, for reference."

    field :name, :string, allow_nil?: false, description: "The habit (`Holy Mass`)."
    field :often, :string, allow_nil?: false, description: "How often (`Daily`, `Weekly`)."

    field :reading_id, :string,
      allow_nil?: false,
      description: "The reading on the `devotions` shelf that tells of it."

    field :act, :string,
      description:
        "The act that does it today, a door `act` target (`mass`, `todays_rosary`), or null."

    field :act_title, :string,
      description: "The act's button (`Pray it`), or null when there is no act."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :carlo_habit
end
