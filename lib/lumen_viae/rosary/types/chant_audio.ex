defmodule LumenViae.Rosary.Types.ChantAudio do
  @moduledoc """
  A chant's recording: a public file named by its checksum.
  """
  use Ash.TypedStruct

  typed_struct do
    field :url, :string,
      allow_nil?: false,
      description:
        "A public, unsigned URL that never changes what it serves: a new recording is a new URL. Cache by it."

    field :bytes, :integer, allow_nil?: false, description: "The file's size."

    field :sha256, :string,
      allow_nil?: false,
      description: "The file's SHA-256, lowercase hex, to check a download against."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_audio
end
