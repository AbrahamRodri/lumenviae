defmodule LumenViae.Rosary.SetMemberships do
  @moduledoc """
  Secondary Context for set memberships: every read and write of the
  `meditation_set_meditations` join table lives here and nowhere else.

  A membership relates a set to a meditation and records the meditation's
  order within the set. This module answers questions about the
  relationship - which meditations are in a set, which sets a meditation
  belongs to, what order comes next - in terms of ids only. It never reads
  the meditations or sets themselves; `LumenViae.Rosary` fetches those from
  their own contexts.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.SetMemberships.SetMembership

  def add(set_id, meditation_id, order) do
    %SetMembership{}
    |> SetMembership.changeset(%{
      meditation_set_id: set_id,
      meditation_id: meditation_id,
      order: order
    })
    |> Repo.insert()
  end

  def remove(set_id, meditation_id) do
    Repo.delete_all(
      from msm in SetMembership,
        where: msm.meditation_set_id == ^set_id and msm.meditation_id == ^meditation_id
    )
  end

  @doc """
  Meditation ids in a set, in the order the set is prayed.
  """
  def list_meditation_ids_in_set(set_id) do
    Repo.all(
      from msm in SetMembership,
        where: msm.meditation_set_id == ^set_id,
        order_by: msm.order,
        select: msm.meditation_id
    )
  end

  @doc """
  Every meditation id that belongs to at least one set.
  """
  def list_member_meditation_ids do
    Repo.all(from msm in SetMembership, distinct: true, select: msm.meditation_id)
  end

  @doc """
  Ids of the sets containing any of the given meditations. Used to work out
  which sets an archived meditation hides.
  """
  def list_set_ids_containing([]), do: []

  def list_set_ids_containing(meditation_ids) do
    Repo.all(
      from msm in SetMembership,
        where: msm.meditation_id in ^meditation_ids,
        distinct: true,
        select: msm.meditation_set_id
    )
  end

  @doc """
  Returns `%{set_id => [meditation_id]}` for every set that has at least one
  meditation, each list in the order the set is prayed.
  """
  def list_meditation_ids_by_set do
    Repo.all(
      from msm in SetMembership,
        order_by: msm.order,
        select: {msm.meditation_set_id, msm.meditation_id}
    )
    |> Enum.group_by(fn {set_id, _} -> set_id end, fn {_, meditation_id} -> meditation_id end)
  end

  @doc """
  Highest order currently used in a set, or 0 when the set is empty, so an
  import can append after it.
  """
  def max_order_in_set(set_id) do
    Repo.one(
      from msm in SetMembership,
        where: msm.meditation_set_id == ^set_id,
        select: max(msm.order)
    ) || 0
  end
end
