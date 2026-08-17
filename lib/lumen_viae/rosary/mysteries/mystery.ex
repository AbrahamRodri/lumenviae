defmodule LumenViae.Rosary.Mysteries.Mystery do
  @moduledoc """
  One of the mysteries of the Rosary.

  Private to `LumenViae.Rosary.Mysteries`; reach mysteries through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.Categories

  schema "mysteries" do
    field :name, :string
    field :category, :string
    field :order, :integer
    field :days_prayed, :string
    field :description, :string
    field :scripture_reference, :string

    has_many :meditations, LumenViae.Rosary.Meditations.Meditation

    timestamps()
  end

  @doc false
  def changeset(mystery, attrs) do
    mystery
    |> cast(attrs, [:name, :category, :order, :days_prayed, :description, :scripture_reference])
    |> validate_required([:name, :category, :order])
    |> validate_inclusion(:category, Categories.slugs())
    |> unique_constraint([:category, :order])
  end
end
