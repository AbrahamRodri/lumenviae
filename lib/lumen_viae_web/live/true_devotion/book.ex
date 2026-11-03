defmodule LumenViaeWeb.Live.TrueDevotion.Book do
  @moduledoc """
  True Devotion as the website's pages read it: the book's title, author
  and translator, its two parts, and its chapters in reading order, over
  `LumenViae.Rosary.get_true_devotion!/1`. How the pages arrange them is
  the iOS app's (`TrueDevotionReaderView`, `TrueDevotionChapterReaderView`):
  the Introduction before the parts, a part named short ("Part I"), a
  chapter's kicker, the versal on a long opening paragraph, and the
  citation a shared passage carries.

  A chapter's text paragraphs are numbered from 1 in the chapter, its
  sub-headings not counted; the number is the paragraph's anchor
  (`#p-3`). The book's data carries no paragraph numbers of its own, and
  Faber's paragraphs do not fall where the standard numbers do, so these
  are the chapter's count and nothing more. Presentation only: it never
  queries beyond `load/1`.
  """

  alias LumenViae.Rosary

  defstruct [:about, :parts, :chapters]

  @opening_quotes ["“", "‘", "\"", "'"]

  @doc "The book, its about, parts and chapters loaded."
  def load(actor) do
    book = Rosary.get_true_devotion!(actor: actor, load: [:about, :parts, :chapters])
    %__MODULE__{about: book.about, parts: book.parts, chapters: book.chapters}
  end

  @doc "The title page's path."
  def path, do: "/true-devotion"

  @doc "A chapter's path, and a paragraph's within it."
  def chapter_path(id), do: "/true-devotion/#{id}"
  def chapter_path(id, paragraph), do: "/true-devotion/#{id}#p-#{paragraph}"

  @doc "The chapter with this id, or nil."
  def chapter(%__MODULE__{chapters: chapters}, id) when is_binary(id),
    do: Enum.find(chapters, &(&1.id == id))

  def chapter(_book, _id), do: nil

  @doc "The chapter's place in the book, from 0."
  def index(%__MODULE__{chapters: chapters}, chapter),
    do: Enum.find_index(chapters, &(&1.id == chapter.id))

  @doc "The chapters either side of this one, nil at either end."
  def neighbours(%__MODULE__{chapters: chapters} = book, chapter) do
    i = index(book, chapter)
    {if(i > 0, do: Enum.at(chapters, i - 1)), Enum.at(chapters, i + 1)}
  end

  @doc """
  The contents as the app sets them: the chapters in no part (the
  Introduction) first, then each part with its chapters.
  """
  def contents(%__MODULE__{parts: parts, chapters: chapters}) do
    free = Enum.filter(chapters, &(&1.part == 0))

    grouped =
      for part <- parts do
        %{part: part, chapters: Enum.filter(chapters, &(&1.part == part.number))}
      end

    {free, grouped}
  end

  @doc "\"Part I\" from \"Part I — On Devotion to Our Lady in General\"."
  def short_part_title(%{title: title}), do: title |> String.split(" — ") |> hd()

  @doc "The words over a chapter's title: its part, short, or the book's title."
  def kicker(%__MODULE__{parts: parts, about: about}, chapter) do
    case Enum.find(parts, &(&1.number == chapter.part)) do
      nil -> about.title
      part -> short_part_title(part)
    end
  end

  @doc """
  A chapter's paragraphs as the page draws them: a `:subheading`, or a
  `:text` with its number in the chapter and whether it opens on the
  app's versal (the chapter's first text paragraph, when it is at least
  80 characters long and does not open on a quotation mark).
  """
  def blocks(chapter) do
    {blocks, _count} =
      Enum.map_reduce(chapter.paragraphs, 0, fn
        %{kind: "text", text: text}, count ->
          n = count + 1
          {%{kind: :text, text: text, number: n, versal?: n == 1 and versal?(text)}, n}

        %{text: text}, count ->
          {%{kind: :subheading, text: text}, count}
      end)

    blocks
  end

  @doc "How many text paragraphs a chapter has."
  def paragraph_count(chapter), do: Enum.count(chapter.paragraphs, &(&1.kind == "text"))

  defp versal?(text), do: String.length(text) >= 80 and String.first(text) not in @opening_quotes

  @doc """
  The line a shared passage carries, as the app's: "— St. Louis-Marie
  Grignion de Montfort, True Devotion to the Blessed Virgin, Introduction
  (trans. Fr. Frederick William Faber). Public domain."
  """
  def citation(%__MODULE__{about: about}, chapter) do
    translator =
      about.translator
      |> String.replace_prefix("Translated by ", "")
      |> String.split(",")
      |> hd()

    "— #{about.author}, #{about.title}, #{chapter.title} (trans. #{translator}). Public domain."
  end

  @doc "A chapter's description for search and link previews: its opening words."
  def description(%__MODULE__{about: about}, chapter) do
    opening =
      Enum.find_value(chapter.paragraphs, "", fn
        %{kind: "text", text: text} -> text
        _ -> nil
      end)

    "#{chapter.title}, from #{about.title} by #{about.author}: #{opening}"
  end
end
