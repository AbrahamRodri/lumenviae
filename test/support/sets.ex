defmodule LumenViae.Test.Sets do
  @moduledoc """
  A set with no meditations is hidden from every public surface, exactly as
  one holding an archived meditation is. A test that wants a set the public
  can see therefore has to put something in it.
  """

  alias LumenViae.Rosary

  @doc """
  Gives a set a meditation, at the next free position, and returns the set.
  `attrs` go to the meditation, for a test that cares what it says.
  """
  def with_meditation(set, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Fixture Mystery #{unique}",
          category: set.category,
          order: 1_000 + unique
        },
        actor: LumenViae.Test.Admins.admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        Map.merge(%{content: "A meditation.", mystery_id: mystery.id}, attrs),
        actor: LumenViae.Test.Admins.admin()
      )

    {:ok, _} =
      Rosary.add_meditation_to_set(set.id, meditation.id, Rosary.next_order_in_set(set.id),
        actor: LumenViae.Test.Admins.admin()
      )

    set
  end
end
