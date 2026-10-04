defmodule LumenViae.Rosary.Types.ScriptTemplateStep do
  @moduledoc """
  One step of a Rosary's template. Expanded, it is a
  `LumenViae.Rosary.Types.ScriptStep`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description:
        "`prayer`, `announcement` (the mystery named), `meditation` (the set's own narration) or `verse` (the Scriptural Rosary's verse for one Hail Mary)."

    field :prayer_id, :string,
      description: "The prayer said, for a `prayer` step: an id in the `prayers` section."

    field :caption, :string,
      allow_nil?: false,
      description:
        "What the screen calls the step. In a `per_bead` step, `{n}` stands for the Hail Mary's number."

    field :bead, :integer,
      description:
        "The bead of the decade's strand it is said on: 0 the Our Father, the strand's `glory_be_bead` the Glory Be. Null in a `per_bead` step, which is said on Hail Mary n's bead, n."

    field :place, :string,
      description: "Where on the pendant it is said, one of `pendant`'s places; null in a decade."

    field :per_bead, :boolean,
      allow_nil?: false,
      description:
        "Said once for each Hail Mary of the decade, with the other `per_bead` steps beside it, in order."

    field :style, :string,
      description:
        "The only style the step is said in (`meditation`, `scriptural`); null in every style."

    field :pause_ms, :integer,
      allow_nil?: false,
      description: "The silence after the step, in milliseconds."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :script_template_step
end
