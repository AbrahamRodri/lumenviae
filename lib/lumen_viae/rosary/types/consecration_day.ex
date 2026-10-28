defmodule LumenViae.Rosary.Types.ConsecrationDay do
  @moduledoc """
  One day of the 33-day Consecration: its theme, its readings and the
  question it leaves for the journal. Its prayers are its phase's.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :number, :integer,
      allow_nil?: false,
      description: "The day, from 1 to 34. Day 34 is Consecration Day, the feast itself."

    field :phase_id, :string,
      allow_nil?: false,
      description: "The phase it belongs to, one of the document's phases."

    field :title, :string,
      allow_nil?: false,
      description: "The day's theme (`The Spirit of the World`)."

    field :readings, {:array, Types.ConsecrationReading},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The day's readings, in the order they are read."

    field :journal_prompt, :string,
      allow_nil?: false,
      description: "The question the day leaves for the journal."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_day
end
