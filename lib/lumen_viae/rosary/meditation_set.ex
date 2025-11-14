defmodule LumenViae.Rosary.MeditationSet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditation_sets" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :intro_audio_url, :string

    many_to_many :meditations, LumenViae.Rosary.Meditation,
      join_through: LumenViae.Rosary.MeditationSetMeditation,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(meditation_set, attrs) do
    meditation_set
    |> cast(attrs, [:name, :category, :description, :intro_audio_url])
    |> validate_required([:name, :category])
    |> validate_inclusion(:category, ["joyful", "sorrowful", "glorious"])
  end
end
