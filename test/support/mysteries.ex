defmodule LumenViae.Test.Mysteries do
  @moduledoc """
  The real mysteries, for a page that shows them by their place in a
  category (the Scripture page). Names and fruits are the app's, from
  `test/support/fixtures/app_mysteries.json`.

  The rows have fixed (category, order) keys, which concurrent tests
  inserting the same keys in another order can deadlock on. Call this only
  from a module that is `async: false`.
  """

  alias LumenViae.Rosary

  @fixture "test/support/fixtures/app_mysteries.json"

  @doc """
  Inserts every mystery the app knows, in prayer order, and returns them.
  `references` gives some of them a scripture reference, by key.
  """
  def seed_app_mysteries(references \\ %{}) do
    @fixture
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("mysteries")
    |> Enum.map(fn %{"key" => key, "name" => name, "fruit" => fruit} ->
      [category, order] = Regex.run(~r/^(.+)_(\d+)$/, key, capture: :all_but_first)

      %{
        name: name,
        fruit: fruit,
        category: category,
        order: String.to_integer(order),
        scripture_reference: Map.get(references, key)
      }
    end)
    |> Enum.sort_by(&{&1.category, &1.order})
    |> Enum.map(fn attrs ->
      {:ok, mystery} = Rosary.create_mystery(attrs, actor: LumenViae.Test.Admins.admin())
      mystery
    end)
  end
end
