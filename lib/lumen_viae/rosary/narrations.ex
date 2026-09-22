defmodule LumenViae.Rosary.Narrations do
  @moduledoc """
  Secondary Context for narrations: every read and write of the
  `meditation_narrations` table lives here and nowhere else.

  A narration is one voice's recording of one meditation. This module
  answers which voices a meditation can be heard in, and records a
  recording once its object is in S3. It never reads the meditations
  themselves; `LumenViae.Rosary` composes the two.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Narrations.Narration

  @doc """
  Every narration of the given meditations, as
  `%{meditation_id => [narration]}`. Meditations with none are absent.
  """
  def list_by_meditation_ids([]), do: %{}

  def list_by_meditation_ids(ids) do
    from(n in Narration, where: n.meditation_id in ^ids, order_by: [asc: n.id])
    |> Repo.all()
    |> Enum.group_by(& &1.meditation_id)
  end

  @doc """
  The narrations of one meditation, oldest first.
  """
  def list_for_meditation(meditation_id) do
    Repo.all(
      from n in Narration,
        where: n.meditation_id == ^meditation_id,
        order_by: [asc: n.id]
    )
  end

  @doc """
  Records that `s3_key` now holds `voice`'s recording of the meditation,
  replacing any earlier record for the same pair. Called after the upload
  succeeded, never before: a row here promises an object exists.
  """
  def upsert(meditation_id, voice, s3_key) do
    now = DateTime.utc_now(:second)

    %Narration{}
    |> Narration.changeset(%{
      meditation_id: meditation_id,
      voice: voice,
      s3_key: s3_key,
      generated_at: now
    })
    |> Repo.insert(
      on_conflict: [set: [s3_key: s3_key, generated_at: now, updated_at: now]],
      conflict_target: [:meditation_id, :voice]
    )
  end

  @doc """
  Forgets `voice`'s recording of the meditation. Does not touch S3.
  """
  def delete(meditation_id, voice) do
    Repo.delete_all(
      from n in Narration,
        where: n.meditation_id == ^meditation_id and n.voice == ^voice
    )
  end

  @doc """
  Meditation ids that have a recording in `voice`.
  """
  def list_meditation_ids_with_voice(voice) do
    Repo.all(from n in Narration, where: n.voice == ^voice, select: n.meditation_id)
  end

  @doc """
  How many meditations each voice has recorded, as `%{voice => count}`.
  """
  def count_by_voice do
    from(n in Narration, group_by: n.voice, select: {n.voice, count(n.id)})
    |> Repo.all()
    |> Map.new()
  end
end
