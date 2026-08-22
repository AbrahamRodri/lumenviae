defmodule LumenViae.Rosary.Authors do
  @moduledoc """
  Secondary Context for authors: every read and write of the `authors`
  table lives here and nowhere else.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  alias LumenViae.Repo
  alias LumenViae.Rosary.Authors.Author

  import Ecto.Query

  def list do
    Repo.all(from a in Author, order_by: a.name)
  end

  def get!(id), do: Repo.get!(Author, id)

  def create(attrs \\ %{}) do
    %Author{}
    |> Author.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Author{} = author, attrs) do
    author
    |> Author.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Author{} = author) do
    Repo.delete(author)
  end

  def change(%Author{} = author, attrs \\ %{}) do
    Author.changeset(author, attrs)
  end

  @doc """
  Records a completed portrait upload: the S3 key and the dimensions
  `LumenViae.Curation.ArtworkUpload` measured, plus any metadata supplied
  with it.
  """
  def update_artwork(%Author{} = author, attrs) do
    author
    |> Author.artwork_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Records the artwork metadata a curator typed. Cannot reach the key or
  the dimensions, so a crafted form post cannot repoint an author at
  another object or desync the stored size.
  """
  def update_artwork_metadata(%Author{} = author, attrs) do
    author
    |> Author.artwork_metadata_changeset(attrs)
    |> Repo.update()
  end

  def change_artwork(%Author{} = author, attrs \\ %{}) do
    Author.artwork_metadata_changeset(author, attrs)
  end
end
