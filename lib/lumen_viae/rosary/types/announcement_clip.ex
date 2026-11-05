defmodule LumenViae.Rosary.Types.AnnouncementClip do
  @moduledoc """
  The recorded announcement of one mystery ("The First Joyful Mystery: The
  Annunciation"), keyed `"<category>_<order>"` as the app keys its
  mysteries, with the words that are spoken.
  """
  use Ash.TypedStruct

  typed_struct do
    field :key, :string, allow_nil?: false
    field :text, :string
    field :file, :string, allow_nil?: false
    field :audio, LumenViae.Rosary.Types.SignedAudio, allow_nil?: false

    field :lines, {:array, LumenViae.Rosary.Types.NarrationLine},
      description:
        "Each line of the recording's words and when it is heard, in seconds, for highlighting the line being read; null when this recording is not timed."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :announcement_clip
end
