defmodule LumenViae.Rosary.Types.TrueDevotionAbout do
  @moduledoc """
  The book True Devotion's reader holds: its title, author and
  translator, and where the text comes from.
  """
  use Ash.TypedStruct

  typed_struct do
    field :title, :string,
      allow_nil?: false,
      description: "The book's title (`True Devotion to the Blessed Virgin`)."

    field :author, :string,
      allow_nil?: false,
      description: "Who wrote it (`St. Louis-Marie Grignion de Montfort`)."

    field :translator, :string,
      allow_nil?: false,
      description: "The translation, as the title page credits it."

    field :source_note, :string,
      allow_nil?: false,
      description: "The edition the text is taken from, and that it is in the public domain."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :true_devotion_about
end
