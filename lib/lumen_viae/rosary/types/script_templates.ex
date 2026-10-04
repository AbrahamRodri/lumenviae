defmodule LumenViae.Rosary.Types.ScriptTemplates do
  @moduledoc """
  The order a Rosary is said in, as templates a client expands offline: the
  `script` section of `GET /api/v2/rosary-content`. See docs/SPOKEN_ROSARY.md,
  "The order a Rosary is said in", for how to expand them.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :styles, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The styles a Rosary is said in: `meditation`, `scriptural`, `plain` (the Rosary Said Aloud)."

    field :rosary, Types.ScriptForm,
      allow_nil?: false,
      description: "The four Rosaries: Joyful, Sorrowful, Glorious and Luminous."

    field :chaplet, Types.ScriptForm,
      allow_nil?: false,
      description: "The Seven Sorrows chaplet, in its Servite form."

    field :closing_extras, {:array, Types.ClosingExtra},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The optional prayers after a Rosary's closing prayer, in the order they are said whatever order they are chosen in."

    field :pendant, {:array, Types.PendantPlace},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The places on the pendant, climbing from the crucifix to the medal."

    field :headings, Types.ScriptHeadings,
      allow_nil?: false,
      description: "What the screen calls the prayers said on the pendant."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_script_templates
end
