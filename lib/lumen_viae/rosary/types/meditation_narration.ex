defmodule LumenViae.Rosary.Types.MeditationNarration do
  @moduledoc """
  A freshly signed narration for one meditation, named by its id: what a
  client holding a stored set asks for when a URL it kept has expired.
  """
  use Ash.TypedStruct

  typed_struct do
    field :meditation_id, LumenViae.Rosary.Types.Id, allow_nil?: false
    field :voice, :string, allow_nil?: false
    field :audio, LumenViae.Rosary.Types.SignedAudio, allow_nil?: false

    field :lines, {:array, LumenViae.Rosary.Types.NarrationLine},
      description:
        "The meditation line by line with each line's start and end in this recording, for following along; null when this recording has not been timed."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :meditation_narration
end
