defmodule LumenViae.Rosary.Types.PrayerTitle do
  @moduledoc """
  A prayer's name in English and Latin (`The Hail Mary`, `Ave Maria`).
  """
  use Ash.TypedStruct

  typed_struct do
    field :en, :string, allow_nil?: false, description: "In English."
    field :la, :string, allow_nil?: false, description: "In Latin."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_title
end
