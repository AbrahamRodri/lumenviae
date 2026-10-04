defmodule LumenViae.Rosary.Types.ScriptStep do
  @moduledoc """
  One step of a Rosary, expanded: what `GET /api/v2/rosary-script` serves
  and `LumenViae.Rosary.PrayerAudio.script/3` returns.
  """
  use Ash.TypedStruct

  typed_struct do
    field :kind, :string,
      allow_nil?: false,
      description: "`prayer`, `announcement`, `meditation` or `verse`."

    field :name, :string,
      allow_nil?: false,
      description:
        "The clip it plays: the prayer id; the mystery's key, `<category>_<order>`, for an announcement or a meditation (the set's own narration); `<key>_<n>` for the verse before Hail Mary n."

    field :mystery, :string, description: "The decade's mystery key; null on the pendant."

    field :caption, :string, allow_nil?: false, description: "What the screen calls it."

    field :phase, :string, allow_nil?: false, description: "`opening`, `decade` or `closing`."

    field :decade, :integer, description: "The decade, counted from 0; null on the pendant."

    field :bead, :integer,
      allow_nil?: false,
      description:
        "The bead of the decade's strand it is said on: 0 the Our Father, n Hail Mary n, one past the last the Glory Be. The opening is said on the first decade's bead 0, the close on the last decade's Glory Be bead."

    field :place, :string, description: "Where on the pendant it is said; null in a decade."

    field :pause_ms, :integer,
      allow_nil?: false,
      description: "The silence after it, in milliseconds."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :script_step
end
