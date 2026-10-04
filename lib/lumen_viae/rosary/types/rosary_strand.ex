defmodule LumenViae.Rosary.Types.RosaryStrand do
  @moduledoc """
  The strand of beads a form's decades are prayed on. A decade is its Our
  Father bead and its Hail Marys; the Glory Be has no bead of its own and
  is said on the next decade's Our Father bead, or after the last decade
  on one final bead.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :decades, :integer,
      allow_nil?: false,
      description: "Decades on the strand: five, or the seven sorrows."

    field :hail_marys, :integer, allow_nil?: false, description: "Hail Marys in each decade."

    field :decade_length, :integer,
      allow_nil?: false,
      description: "Beads in a decade: its Our Father and its Hail Marys."

    field :beads, :integer,
      allow_nil?: false,
      description: "Every bead on the strand, the final bead included."

    field :glory_be_bead, :integer,
      allow_nil?: false,
      description:
        "The bead of a decade the Glory Be is said on: one past its last Hail Mary, which is the next decade's Our Father bead."

    field :fatima_prayer, :boolean,
      allow_nil?: false,
      description: "Whether a decade closes with the Fatima Prayer after its Glory Be."

    field :labels, Types.BeadLabels,
      allow_nil?: false,
      description: "What the bead under the hand is called."

    field :label_lines, Types.BeadLabelLines,
      allow_nil?: false,
      description: "The same names broken for a narrow margin."

    field :strand_labels, Types.StrandLabels,
      allow_nil?: false,
      description: "The labels drawn beside the strand."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_strand
end
