defmodule LumenViae.Rosary.Authors.Author do
  @moduledoc """
  A person whose writings the meditations are drawn from.

  Carries the one image that stands in for every set by this author that
  has no artwork of its own, so a portrait is uploaded once rather than
  once per set.

  Private to `LumenViae.Rosary.Authors`; reach authors through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.Artwork

  schema "authors" do
    field :name, :string

    # Artwork. Written by the two changesets below, never by `changeset/2`,
    # for the same reason the split exists on `MeditationSet`.
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

    timestamps()
  end

  @doc false
  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  @doc """
  Records a completed upload: the key and dimensions `ArtworkUpload` has
  just proved, plus any metadata supplied with it.
  """
  def artwork_changeset(author, attrs), do: Artwork.cast_upload(author, attrs)

  @doc """
  Records what the curator typed. Cannot touch the key or the dimensions.
  """
  def artwork_metadata_changeset(author, attrs), do: Artwork.cast_metadata(author, attrs)
end
