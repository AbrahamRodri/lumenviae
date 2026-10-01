defmodule LumenViae.Rosary.Types.SignedNarration do
  @moduledoc """
  One voice's recording of a meditation, as a URL a client can play now:
  the voice's slug and the signed audio.
  """
  use Ash.TypedStruct

  typed_struct do
    field :voice, :string, allow_nil?: false
    field :audio, LumenViae.Rosary.Types.SignedAudio, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :signed_narration
end
