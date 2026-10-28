defmodule LumenViae.Rosary.Types.ChantScorePart do
  @moduledoc """
  One page of a chant's sheet music: a public file named by its checksum,
  a packed drawing the app renders (`.lvscore`).
  """
  use Ash.TypedStruct

  typed_struct do
    field :file, :string,
      allow_nil?: false,
      description:
        "The score's name (`chant-salve-regina-simple`). Chants share some (`chant-vers-alt-ora-pro-nobis`)."

    field :caption, :string, allow_nil?: false, description: "What the page holds."

    field :aspect_ratio, :float,
      allow_nil?: false,
      description: "Width over height, to lay out the page before it is drawn."

    field :url, :string,
      allow_nil?: false,
      description:
        "A public, unsigned URL that never changes what it serves: a new drawing is a new URL. Cache by it."

    field :bytes, :integer, allow_nil?: false, description: "The file's size."

    field :sha256, :string,
      allow_nil?: false,
      description: "The file's SHA-256, lowercase hex, to check a download against."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :chant_score_part
end
