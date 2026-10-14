defmodule LumenViae.Rosary.Types.Chant do
  @moduledoc """
  One chant of the Chant Library, as `GET /api/v2/chant-library` serves
  it: its titles, its recording, its sheet music and its timed lines.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The chant's id. Stable forever: a device stores it for favourites."

    field :group_id, :string, allow_nil?: false, description: "The group it belongs to."
    field :latin_title, :string, allow_nil?: false, description: "Its Latin title."
    field :english_title, :string, allow_nil?: false, description: "Its English title."

    field :setting, :string,
      description: "Which melody, where there is more than one (`Simple melody`), or null."

    field :detail, :string, allow_nil?: false, description: "When it is sung, in one line."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The prayers it sings. A client takes the first chant listed for a prayer."

    field :duration, :float, allow_nil?: false, description: "The recording's length in seconds."

    field :source_url, :string,
      allow_nil?: false,
      description: "Where the recording and score were published (Verbum Gloriae)."

    field :audio, Types.ChantAudio, allow_nil?: false, description: "The recording."

    field :score, {:array, Types.ChantScorePart},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The sheet music, page by page in order."

    field :lines, {:array, Types.ChantLine},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The words as sung, timed to the recording, in order. Empty when not timed."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant
end
