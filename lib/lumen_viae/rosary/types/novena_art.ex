defmodule LumenViae.Rosary.Types.NovenaArt do
  @moduledoc """
  A novena's painting as a public file named by its checksum, as a chant's
  recording is, with the credit to print under it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :url, :string,
      allow_nil?: false,
      description:
        "A public, unsigned URL that never changes what it serves: a new painting is a new URL. Cache by it."

    field :bytes, :integer, allow_nil?: false, description: "The file's size."

    field :sha256, :string,
      allow_nil?: false,
      description: "The file's SHA-256, lowercase hex, to check a download against."

    field :credit, :string,
      allow_nil?: false,
      description: "The painter, the date and that it is in the public domain, as printed."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :novena_art
end
