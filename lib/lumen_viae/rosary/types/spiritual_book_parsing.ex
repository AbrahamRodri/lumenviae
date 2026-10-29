defmodule LumenViae.Rosary.Types.SpiritualBookParsing do
  @moduledoc """
  The rules that cut one Gutenberg edition into chapters
  (`LibraryParsingRules` in the iOS app). Each pattern is a regular
  expression in ICU syntax, which Java's `java.util.regex` reads the same
  way for these, matched against one line of the text at a time with its
  surrounding spaces trimmed.
  """
  use Ash.TypedStruct

  typed_struct do
    field :chapter_pattern, :string,
      allow_nil?: false,
      description: "A line that opens a chapter (`^CHAPTER [IVXLC]+$`)."

    field :part_pattern, :string,
      description:
        "A line that opens a part holding chapters (`^THE (FIRST|SECOND|THIRD|FOURTH) BOOK$`), or null."

    field :start_pattern, :string,
      description:
        "The line the book starts at; everything above it (the contents, a preface) is skipped. Null: the first chapter line."

    field :stop_pattern, :string,
      description:
        "The line the book ends before, once its body has begun (an appendix, the footnotes), or null."

    field :note_pattern, :string,
      description:
        "A footnote or citation marker in the prose (`\\(\\d+\\)`), taken out of a quoted paragraph, or null."

    field :drop_pattern, :string,
      description: "Lines left out wherever they stand (printer's half-titles), or null."

    field :title_runs_to_blank_gap, :boolean,
      allow_nil?: false,
      description:
        "Whether a chapter's title may run over blocks separated by a single blank line, rather than stopping at the first block."

    field :minimum_chapter_length, :integer,
      allow_nil?: false,
      description:
        "Characters a chapter must hold to count, so a contents page's line does not open a chapter. 500 unless set."

    field :maximum_title_length, :integer,
      allow_nil?: false,
      description: "The longest a chapter's title may be, in characters. 140 unless set."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :spiritual_book_parsing
end
