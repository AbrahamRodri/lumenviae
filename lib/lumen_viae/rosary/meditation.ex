defmodule LumenViae.Rosary.Meditation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditations" do
    field :title, :string
    field :content, :string
    field :author, :string
    field :source, :string
    field :audio_url, :string

    belongs_to :mystery, LumenViae.Rosary.Mystery

    many_to_many :meditation_sets, LumenViae.Rosary.MeditationSet,
      join_through: LumenViae.Rosary.MeditationSetMeditation

    timestamps()
  end

  @doc false
  def changeset(meditation, attrs) do
    meditation
    |> cast(attrs, [:title, :content, :author, :source, :mystery_id, :audio_url])
    |> validate_required([:content, :mystery_id])
  end
end
