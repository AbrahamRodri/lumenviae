defmodule LumenViae.Rosary.Types.ConsecrationReading do
  @moduledoc """
  One reading of a Consecration day: a Gospel passage, a chapter of the
  Imitation of Christ or paragraphs of True Devotion, each with its own
  citation and source.
  """
  use Ash.TypedStruct

  typed_struct do
    field :order, :integer,
      allow_nil?: false,
      description: "Its place in the day, counting from 1."

    field :title, :string,
      allow_nil?: false,
      description: "Its citation (`Matthew 5:1-19`, `True Devotion, paragraph 227`)."

    field :text, :string,
      allow_nil?: false,
      description:
        "The reading, in the app's ReadingText grammar: paragraphs parted by a blank line, a paragraph starting `# ` a heading."

    field :source, :string,
      description:
        "The work it comes from (`Douay-Rheims Bible`, `Thomas à Kempis`, `St. Louis de Montfort`), or null."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_reading
end
