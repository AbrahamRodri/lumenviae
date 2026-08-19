defmodule LumenViae.Rosary.MeditationSets.MeditationSet do
  @moduledoc """
  A curated collection of meditations prayed together as one Rosary.

  Private to `LumenViae.Rosary.MeditationSets`; reach sets through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Labels

  schema "meditation_sets" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :labels, {:array, :string}, default: []

    # Artwork. Written by the two changesets below, never by `changeset/2`,
    # for the same reason `archived_at` is not castable on `Meditation`.
    field :image_key, :string
    field :image_width, :integer
    field :image_height, :integer
    field :image_focal_x, :float, default: 0.5
    field :image_focal_y, :float, default: 0.5
    field :image_alt, :string
    field :image_title, :string
    field :image_artist, :string
    field :image_year, :string
    field :image_source_url, :string
    field :image_license, :string
    field :image_updated_at, :utc_datetime

    many_to_many :meditations, LumenViae.Rosary.Meditations.Meditation,
      join_through: LumenViae.Rosary.SetMemberships.SetMembership,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(meditation_set, attrs) do
    meditation_set
    |> cast(attrs, [:name, :category, :description, :labels])
    |> validate_required([:name, :category])
    |> validate_inclusion(:category, Categories.slugs())
    |> normalize_labels()
    |> validate_subset(:labels, Labels.vocabulary(),
      message: "contains a label outside the managed vocabulary"
    )
    |> validate_length(:labels,
      max: Labels.max_per_set(),
      message: "cannot have more than #{Labels.max_per_set()} labels"
    )
  end

  @doc """
  Records a completed upload: the key and dimensions `ArtworkUpload` has
  just proved, plus any metadata supplied with it.
  """
  def artwork_changeset(set, attrs), do: Artwork.cast_upload(set, attrs)

  @doc """
  Records what the curator typed. Cannot touch the key or the dimensions.
  """
  def artwork_metadata_changeset(set, attrs), do: Artwork.cast_metadata(set, attrs)

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
