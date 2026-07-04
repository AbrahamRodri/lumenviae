defmodule LumenViae.Rosary.MeditationSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.Labels

  schema "meditation_sets" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :labels, {:array, :string}, default: []

    many_to_many :meditations, LumenViae.Rosary.Meditation,
      join_through: LumenViae.Rosary.MeditationSetMeditation,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(meditation_set, attrs) do
    meditation_set
    |> cast(attrs, [:name, :category, :description, :labels])
    |> validate_required([:name, :category])
    |> validate_inclusion(:category, ["joyful", "sorrowful", "glorious", "seven_sorrows"])
    |> normalize_labels()
    |> validate_subset(:labels, Labels.vocabulary(),
      message: "contains a label outside the managed vocabulary"
    )
    |> validate_length(:labels,
      max: Labels.max_per_set(),
      message: "cannot have more than #{Labels.max_per_set()} labels"
    )
  end

  # Labels are matched by the iOS app as exact case-sensitive strings and the
  # first label is the set's primary group, so keep the list deduplicated
  # while preserving the curated order.
  defp normalize_labels(changeset) do
    update_change(changeset, :labels, fn
      nil -> []
      labels -> Enum.uniq(labels)
    end)
  end
end
