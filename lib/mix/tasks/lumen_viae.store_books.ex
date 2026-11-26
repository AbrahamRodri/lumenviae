defmodule Mix.Tasks.LumenViae.StoreBooks do
  @shortdoc "Fetches the Spiritual Reading books from Gutenberg and stores their text"

  @moduledoc """
  Writes each Spiritual Reading book's text to
  `priv/library/books/pg<gutenberg_id>.txt`, the copy the website reads
  (`Rosary.fetch_stored_book_body/1`): the edition's body without
  Gutenberg's header and licence, written only when it cuts into the same
  chapters as the whole download.

      mix lumen_viae.store_books                  # every book on the shelf
      mix lumen_viae.store_books story-of-a-soul  # one book, by its id
      mix lumen_viae.store_books --mirror https://gutenberg.pglaf.org

  `--mirror` fetches the same `/cache/epub/<id>/pg<id>.txt` files from a
  Gutenberg mirror, for when www.gutenberg.org is down.

  Run it when a book joins the shelf or its edition is to be refreshed, and
  commit the files it writes. Nothing else fetches them.
  """

  use Mix.Task

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Library

  @folder "priv/library/books"

  @impl true
  def run(args) do
    {opts, ids} = OptionParser.parse!(args, strict: [mirror: :string])
    Mix.Task.run("app.config")
    {:ok, _apps} = Application.ensure_all_started(:req)

    if mirror = opts[:mirror] do
      config = Application.get_env(:lumen_viae, :spiritual_reading, [])

      Application.put_env(
        :lumen_viae,
        :spiritual_reading,
        Keyword.put(config, :base_url, String.trim_trailing(mirror, "/"))
      )
    end

    books = Library.served(:spiritual_reading, "books")
    books = if ids == [], do: books, else: Enum.filter(books, &(&1.id in ids))

    if books == [], do: Mix.raise("No book on the shelf has the id #{Enum.join(ids, ", ")}")

    File.mkdir_p!(@folder)

    failed =
      Enum.reject(books, fn info ->
        case Rosary.fetch_stored_book_body(info) do
          {:ok, body} ->
            path = Path.join(@folder, Rosary.stored_book_file(info.gutenberg_id))
            File.write!(path, body)
            Mix.shell().info("#{info.id}: #{path}, #{byte_size(body)} bytes")
            true

          {:error, reason} ->
            Mix.shell().error("#{info.id} (Gutenberg #{info.gutenberg_id}): #{inspect(reason)}")
            false
        end
      end)

    if failed != [], do: Mix.raise("#{length(failed)} book(s) not stored")
  end
end
