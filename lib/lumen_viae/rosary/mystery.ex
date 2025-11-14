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
    field :announcement_audio_url, :string
    field :description_audio_url, :string

    has_many :meditations, LumenViae.Rosary.Meditation

    timestamps()
  end

  @doc false
  def changeset(mystery, attrs) do
    mystery
    |> cast(attrs, [
      :name,
      :category,
      :order,
      :days_prayed,
      :description,
      :scripture_reference,
      :announcement_audio_url,
      :description_audio_url
    ])
    |> validate_required([:name, :category, :order])
    |> validate_inclusion(:category, ["joyful", "sorrowful", "glorious"])
    |> validate_number(:order, greater_than: 0, less_than_or_equal_to: 5)
    |> unique_constraint([:category, :order])
  end
end
