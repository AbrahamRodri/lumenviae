defmodule LumenViae.Rosary.Mysteries do
  @moduledoc """
  Secondary Context for mysteries: every read and write of the `mysteries`
  table lives here and nowhere else.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Mysteries.Mystery

  def count do
    Repo.aggregate(Mystery, :count)
  end

  @doc """
  Lists mysteries in the order they are prayed: by category, then by
  position within the category.
  """
  def list do
    Repo.all(from m in Mystery, order_by: [m.category, m.order])
  end

  def list_by_category(category) do
    Repo.all(from m in Mystery, where: m.category == ^category, order_by: m.order)
  end

  def get!(id), do: Repo.get!(Mystery, id)

  def create(attrs \\ %{}) do
    %Mystery{}
    |> Mystery.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Mystery{} = mystery, attrs) do
    mystery
    |> Mystery.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Mystery{} = mystery) do
    Repo.delete(mystery)
  end

  def change(%Mystery{} = mystery, attrs \\ %{}) do
    Mystery.changeset(mystery, attrs)
  end
end
