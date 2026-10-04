defmodule LumenViae.Test.Sets do
  @moduledoc """
  A set with no meditations is hidden from every public surface, exactly as
  one holding an archived meditation is. A test that wants a set the public
  can see therefore has to put something in it.

  The other way round: a meditation in no set at all is a draft, and the
  public cannot read it or its audio (A6). A test that wants a meditation
  the public can reach puts it in a set (`put_in_a_set/1`).
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

  @doc """
  Puts a meditation in a set of its own, and returns the meditation. The
  set is visible while the meditation is not archived, and hidden after,
  which is the case a saved set on a device lives through.
  """
  def put_in_a_set(meditation) do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Fixture Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: LumenViae.Test.Admins.admin()
      )

    {:ok, _} =
      Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: LumenViae.Test.Admins.admin())

    meditation
  end
end
