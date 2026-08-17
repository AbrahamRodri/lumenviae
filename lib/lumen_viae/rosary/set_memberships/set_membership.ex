defmodule LumenViae.Rosary.SetMemberships.SetMembership do
  @moduledoc """
  One meditation's place in one meditation set.

  The join row carries the meditation's `order` within the set, which is why
  membership is a resource in its own right rather than a bare many-to-many.

  Private to `LumenViae.Rosary.SetMemberships`; reach memberships through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditation_set_meditations" do
    field :order, :integer

    belongs_to :meditation_set, LumenViae.Rosary.MeditationSets.MeditationSet
    belongs_to :meditation, LumenViae.Rosary.Meditations.Meditation

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
