defmodule LumenViae.Rosary.Mystery do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mysteries" do
    field :name, :string
    field :category, :string
    field :order, :integer
    field :days_prayed, :string
    field :description, :string
    field :scripture_reference, :string

    has_many :meditations, LumenViae.Rosary.Meditation

    timestamps()
  end

  @doc false
  def changeset(mystery, attrs) do
    mystery
    |> cast(attrs, [:name, :category, :order, :days_prayed, :description, :scripture_reference])
    |> validate_required([:name, :category, :order])
    |> validate_inclusion(:category, ["joyful", "sorrowful", "glorious", "seven_sorrows"])
    |> unique_constraint([:category, :order])
  end
end
