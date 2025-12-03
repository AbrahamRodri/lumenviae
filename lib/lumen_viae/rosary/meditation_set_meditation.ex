defmodule LumenViae.Rosary.MeditationSetMeditation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditation_set_meditations" do
    field :order, :integer

    belongs_to :meditation_set, LumenViae.Rosary.MeditationSet
    belongs_to :meditation, LumenViae.Rosary.Meditation

    timestamps()
  end

  @doc false
  def changeset(meditation_set_meditation, attrs) do
    meditation_set_meditation
    |> cast(attrs, [:meditation_set_id, :meditation_id, :order])
    |> validate_required([:meditation_set_id, :meditation_id, :order])
    |> validate_number(:order, greater_than: 0, less_than_or_equal_to: 7)
    |> unique_constraint([:meditation_set_id, :meditation_id])
    |> unique_constraint([:meditation_set_id, :order])
  end
end
