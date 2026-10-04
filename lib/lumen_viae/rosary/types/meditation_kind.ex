defmodule LumenViae.Rosary.Types.MeditationKind do
  @moduledoc """
  One kind of meditation: the label, what praying with it is like, and a few of the voices that carry it.
  """
  use Ash.TypedStruct

  typed_struct do
    field :label, :string,
      allow_nil?: false,
      description: "The stored label it explains."

    field :icon, :string,
      allow_nil?: false,
      description: "The glyph, by the iOS app's icon name."

    field :title, :string,
      allow_nil?: false,
      description: "A short heading."

    field :description, :string,
      allow_nil?: false,
      description:
        "What it is like, then, after a blank line, the voices that carry it. The voices are examples, not an index: the library grows."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :meditation_kind
end
