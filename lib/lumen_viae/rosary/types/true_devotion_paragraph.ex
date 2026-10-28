defmodule LumenViae.Rosary.Types.TrueDevotionParagraph do
  @moduledoc """
  One paragraph of a True Devotion chapter: the text, or a subheading
  inside the chapter.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :integer,
      allow_nil?: false,
      description:
        "Its place in the chapter, counting from 0. Stable forever with the chapter's id: a device keeps a reader's place by the two."

    field :kind, :string,
      allow_nil?: false,
      description:
        "`text`, a paragraph of the book, or `subheading`, a heading inside the chapter."

    field :text, :string,
      allow_nil?: false,
      description: "The words, as printed. No markup."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :true_devotion_paragraph
end
