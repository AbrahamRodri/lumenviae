defmodule LumenViae.Rosary.Types.SpiritualBook do
  @moduledoc """
  A book on the Spiritual Reading shelf, as the iOS app's
  `Data/LibraryCatalog.swift` holds it: who wrote it, where its text and
  its recording come from, and the rules that cut that edition into
  chapters and line its recording up with them. The text and the
  recording are never served here: a device fetches them from Project
  Gutenberg and LibriVox itself.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "Stable forever (`imitation-of-christ`): devices store a reader's place by it."

    field :title, :string, allow_nil?: false, description: "Its title."
    field :author, :string, allow_nil?: false, description: "Its author (`Thomas à Kempis`)."

    field :translator, :string, description: "The translator of this edition's English, or null."

    field :blurb, :string, allow_nil?: false, description: "One line saying what it is."

    field :gutenberg_id, :integer,
      allow_nil?: false,
      description:
        "Its Project Gutenberg ebook number. The text is `https://www.gutenberg.org/cache/epub/<id>/pg<id>.txt`."

    field :librivox_id, :integer,
      description:
        "The LibriVox audiobook read from this same translation, or null when none is offered (a recording of another English is never offered as this text's)."

    field :track_mapping, Types.SpiritualBookTrackMapping,
      allow_nil?: false,
      description: "How the recording's tracks line up with the chapters."

    field :preferred_rate, :float,
      allow_nil?: false,
      description: "The playback rate the recording opens at (1.5 for a slow reader)."

    field :parsing, Types.SpiritualBookParsing,
      allow_nil?: false,
      description: "How the Gutenberg text is cut into chapters."

    field :chapter_titles, {:array, :string},
      description:
        "A title for each chapter, in order, for an edition that prints none (the Confessions' books), or null. A printed title wins over these."

    field :heading_overrides, {:array, Types.SpiritualBookHeading},
      allow_nil?: false,
      description:
        "Chapters whose printed heading is replaced, by their index from 0. Usually empty."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book
end
