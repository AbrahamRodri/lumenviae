defmodule LumenViae.Rosary.Types.BeadLabelLines do
  @moduledoc """
  The bead names broken into lines for a narrow margin. `{n}` is the Hail
  Mary's number.
  """
  use Ash.TypedStruct

  typed_struct do
    field :our_father, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "An Our Father bead."

    field :hail_mary, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "Hail Mary n's bead."

    field :glory_be, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The Glory Be's bead."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :bead_label_lines
end
