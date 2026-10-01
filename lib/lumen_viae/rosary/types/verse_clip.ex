defmodule LumenViae.Rosary.Types.VerseClip do
  @moduledoc """
  The Scriptural Rosary's verse for one Hail Mary bead: `bead` is the Hail
  Mary it is said before, counting from 1.
  """
  use Ash.TypedStruct

  typed_struct do
    field :bead, :integer, allow_nil?: false
    field :reference, :string
    field :file, :string, allow_nil?: false
    field :audio, LumenViae.Rosary.Types.SignedAudio, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :verse_clip
end
