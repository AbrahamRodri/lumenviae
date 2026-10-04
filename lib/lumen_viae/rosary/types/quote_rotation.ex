defmodule LumenViae.Rosary.Types.QuoteRotation do
  @moduledoc """
  How a client chooses a quotation: the device's day of the year (January 1 is 1, in the device's calendar) plus an offset, modulo the number of quotations.
  """
  use Ash.TypedStruct

  typed_struct do
    field :home_offset, :integer,
      allow_nil?: false,
      description:
        "The offset for the home screen's quotation: `items[(day_of_year + home_offset) mod count]`."

    field :after_prayer_offset_divisor, :integer,
      allow_nil?: false,
      description:
        "The offset for the quotation after praying is the number of quotations divided by this, rounded down: `items[(day_of_year + count div divisor) mod count]`, half the catalogue from the home screen's so one session never shows one line twice."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :quote_rotation
end
