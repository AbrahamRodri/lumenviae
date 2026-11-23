defmodule LumenViae.Rosary.SpiritualReading.Stored do
  @moduledoc """
  The Spiritual Reading shelf's texts as the release carries them:
  `priv/library/books/pg<gutenberg_id>.txt`, each edition's body between
  Project Gutenberg's START and END markers, without their header and
  licence (the books are credited to their printed editions on /credits).

  `LumenViae.Rosary.SpiritualReading.Text` reads a book from here before
  it asks Gutenberg, so a deploy, which empties the in-memory cache, never
  depends on Gutenberg answering. A copy changes only on purpose, with
  `mix lumen_viae.store_books`, which fetches the edition again and writes
  it only when it cuts into the same chapters through the stored body as
  through the whole download.

  The suite turns this off (`config :lumen_viae, :spiritual_reading,
  stored: false`), so its Gutenberg stubs are what a test reads.
  """

  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.Parser

  @folder "priv/library/books"

  @doc "The stored text of Gutenberg ebook `id`: `{:ok, text}`, or `:none`."
  def read(id) when is_integer(id) do
    with true <- enabled?(),
         {:ok, text} <- File.read(path(id)) do
      {:ok, text}
    else
      _ -> :none
    end
  end

  @doc "Where the release keeps ebook `id`'s text."
  def path(id), do: Path.join(Application.app_dir(:lumen_viae, @folder), file(id))

  @doc "The file's name: `pg16772.txt`."
  def file(id), do: "pg#{id}.txt"

  @doc """
  Fetches `info`'s edition from Gutenberg and answers the body to store,
  `{:ok, body}`, once the body cuts into the same chapters as the whole
  download; `{:error, reason}` otherwise. Writes nothing.
  """
  def fetch_body(info) do
    with {:ok, text} <- Gutenberg.fetch_text(info.gutenberg_id) do
      text = utf8(text)
      body = Parser.strip_envelope(text)
      whole = Parser.parse(text, info)

      cond do
        whole.chapters == [] -> {:error, :cuts_into_no_chapters}
        Parser.parse(body, info) != whole -> {:error, :body_cuts_differently}
        true -> {:ok, body}
      end
    end
  end

  # Text's own rule: bytes that are not UTF-8 are read as Latin-1.
  defp utf8(text) do
    if String.valid?(text), do: text, else: :unicode.characters_to_binary(text, :latin1)
  end

  defp enabled? do
    :lumen_viae |> Application.get_env(:spiritual_reading, []) |> Keyword.get(:stored, true)
  end
end
