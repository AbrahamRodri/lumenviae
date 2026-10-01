defmodule LumenViae.Rosary.Types.RosaryClip do
  @moduledoc """
  One recorded prayer of the spoken Rosary or of the Prayer Book, keyed by
  the app's prayer id. `title` is the Prayer Book's heading; the Rosary's
  own prayers have none. `file` is the recording's name in S3, the device's
  cache key, and changes exactly when the recording does.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false
    field :title, :string
    field :file, :string, allow_nil?: false
    field :audio, LumenViae.Rosary.Types.SignedAudio, allow_nil?: false
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_clip
end
