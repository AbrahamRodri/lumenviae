defmodule LumenViae.Rosary.Narrations.Narration do
  @moduledoc """
  One voice's recording of one meditation: the S3 object that exists for
  that pair, and when it was generated.

  A meditation has at most one narration per voice. The voice is the slug
  of a configured `LumenViae.Rosary.Voices` entry rather than a foreign
  key, because voices are configuration, not rows.

  Private to `LumenViae.Rosary.Narrations`; reach narrations through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "meditation_narrations" do
    field :voice, :string
    field :s3_key, :string
    field :generated_at, :utc_datetime

    belongs_to :meditation, LumenViae.Rosary.Meditations.Meditation

    timestamps()
  end

  @doc false
  def changeset(narration, attrs) do
    narration
    |> cast(attrs, [:meditation_id, :voice, :s3_key, :generated_at])
    |> validate_required([:meditation_id, :voice, :s3_key, :generated_at])
    |> validate_format(:voice, ~r/^[a-z0-9_-]+$/,
      message: "must be a lowercase slug (letters, digits, - and _)"
    )
    |> unique_constraint([:meditation_id, :voice])
  end
end
