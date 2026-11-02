defmodule LumenViae.Rosary.Types.PrayerTitle do
  @moduledoc """
  A prayer's name in English and Latin (`The Hail Mary`, `Ave Maria`), and
  in Spanish (`Ave María`) when asked for.
  """
  use Ash.TypedStruct

  typed_struct do
    field :en, :string, allow_nil?: false, description: "In English."
    field :la, :string, allow_nil?: false, description: "In Latin."

    field :es, :string,
      description:
        "In Spanish. Only with `lang=es`, and then always present: the English where there is no Spanish yet. An English document has no `es` at all."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :prayer_title
end
