defmodule LumenViae.Rosary.RosaryCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.MeditationSet

  schema "rosary_completions" do
    field :completed_at, :utc_datetime
    field :ip_address, :string
    field :city, :string
    field :region, :string
    field :country, :string
    field :country_code, :string

    belongs_to :meditation_set, MeditationSet

    timestamps(updated_at: false)
  end

  def changeset(rosary_completion, attrs) do
    rosary_completion
    |> cast(attrs, [:meditation_set_id, :completed_at, :ip_address, :city, :region, :country, :country_code])
    |> validate_required([:meditation_set_id, :completed_at])
    |> foreign_key_constraint(:meditation_set_id)
  end
end
