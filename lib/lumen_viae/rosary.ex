defmodule LumenViae.Rosary do
  @moduledoc """
  The Rosary context.
  """

  import Ecto.Query, warn: false
  alias LumenViae.Repo

  alias LumenViae.Rosary.{Mystery, Meditation, MeditationSet, MeditationSetMeditation}

  ## Mysteries

  def list_mysteries do
    Repo.all(from m in Mystery, order_by: [m.category, m.order])
  end

  def list_mysteries_by_category(category) do
    Repo.all(from m in Mystery, where: m.category == ^category, order_by: m.order)
  end

  def get_mystery!(id), do: Repo.get!(Mystery, id)

  def create_mystery(attrs \\ %{}) do
    %Mystery{}
    |> Mystery.changeset(attrs)
    |> Repo.insert()
  end

  ## Meditations

  def list_meditations do
    Repo.all(Meditation) |> Repo.preload(:mystery)
  end

  def list_meditations_by_mystery(mystery_id) do
    Repo.all(from m in Meditation, where: m.mystery_id == ^mystery_id)
  end

  def get_meditation!(id) do
    Repo.get!(Meditation, id) |> Repo.preload(:mystery)
  end

  def create_meditation(attrs \\ %{}) do
    %Meditation{}
    |> Meditation.changeset(attrs)
    |> Repo.insert()
  end

  def update_meditation(%Meditation{} = meditation, attrs) do
    meditation
    |> Meditation.changeset(attrs)
    |> Repo.update()
  end

  def change_meditation(%Meditation{} = meditation, attrs \\ %{}) do
    Meditation.changeset(meditation, attrs)
  end

  def delete_meditation(%Meditation{} = meditation) do
    Repo.delete(meditation)
  end

  @doc """
  Generates a pre-signed URL for a meditation's audio file.

  Returns the pre-signed URL string if the meditation has an audio_url (S3 key),
  or nil if no audio is available or if URL generation fails.

  ## Examples

      iex> get_meditation_audio_url(%Meditation{audio_url: "meditation1.mp3"})
      "https://lumenviae-audio.s3.us-east-2.amazonaws.com/meditation1.mp3?..."

      iex> get_meditation_audio_url(%Meditation{audio_url: nil})
      nil
  """
  def get_meditation_audio_url(%Meditation{audio_url: nil}), do: nil
  def get_meditation_audio_url(%Meditation{audio_url: ""}), do: nil

  def get_meditation_audio_url(%Meditation{audio_url: s3_key}) when is_binary(s3_key) do
    LumenViae.Storage.S3.generate_presigned_url!(s3_key)
  end

  ## Meditation Sets

  def list_meditation_sets do
    Repo.all(MeditationSet)
  end

  def list_meditation_sets_by_category(category) do
    Repo.all(from ms in MeditationSet, where: ms.category == ^category)
  end

  def get_meditation_set!(id) do
    Repo.get!(MeditationSet, id)
    |> Repo.preload(meditations: from(m in Meditation, order_by: m.id))
  end

  def get_meditation_set_with_ordered_meditations!(id) do
    set = Repo.get!(MeditationSet, id)

    meditations =
      from(m in Meditation,
        join: msm in MeditationSetMeditation,
        on: msm.meditation_id == m.id,
        where: msm.meditation_set_id == ^id,
        order_by: msm.order,
        preload: [:mystery]
      )
      |> Repo.all()

    %{set | meditations: meditations}
  end

  def create_meditation_set(attrs \\ %{}) do
    %MeditationSet{}
    |> MeditationSet.changeset(attrs)
    |> Repo.insert()
  end

  def update_meditation_set(%MeditationSet{} = meditation_set, attrs) do
    meditation_set
    |> MeditationSet.changeset(attrs)
    |> Repo.update()
  end

  def change_meditation_set(%MeditationSet{} = meditation_set, attrs \\ %{}) do
    MeditationSet.changeset(meditation_set, attrs)
  end

  def delete_meditation_set(%MeditationSet{} = meditation_set) do
    Repo.delete(meditation_set)
  end

  ## Meditation Set Meditations (Join Table)

  def add_meditation_to_set(meditation_set_id, meditation_id, order) do
    %MeditationSetMeditation{}
    |> MeditationSetMeditation.changeset(%{
      meditation_set_id: meditation_set_id,
      meditation_id: meditation_id,
      order: order
    })
    |> Repo.insert()
  end

  def remove_meditation_from_set(meditation_set_id, meditation_id) do
    Repo.delete_all(
      from msm in MeditationSetMeditation,
        where: msm.meditation_set_id == ^meditation_set_id and msm.meditation_id == ^meditation_id
    )
  end
end
