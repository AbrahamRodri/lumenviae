defmodule LumenViae.Rosary.Types.ScriptForm do
  @moduledoc """
  One form of the Rosary as templates: the steps of its opening, of each
  decade, of its close and of its last words, and the rules of its strand.
  A Rosary is `opening`, then `decade` once for each mystery, then
  `closing`, then the chosen `closing_extras` if the form takes them, then
  `final`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :categories, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The mystery categories prayed in this form."

    field :takes_extras, :boolean,
      allow_nil?: false,
      description: "Whether the optional prayers after the Rosary are said in this form."

    field :opening, {:array, Types.ScriptTemplateStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The prayers on the pendant before the first decade."

    field :decade, {:array, Types.ScriptTemplateStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "One decade. The run of steps marked `per_bead` is said once for each Hail Mary, in order; a step with a `style` is said only in that style."

    field :closing, {:array, Types.ScriptTemplateStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The prayers after the last decade, before any optional prayers."

    field :final, {:array, Types.ScriptTemplateStep},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The last words, after any optional prayers."

    field :strand, Types.RosaryStrand,
      allow_nil?: false,
      description: "The strand of beads the decades are prayed on."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :script_form
end
