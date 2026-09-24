defmodule LumenViae.Rosary.Completions.Completion do
  @moduledoc """
  A record that someone finished praying a meditation set, with the
  approximate place and the surface it was prayed from. Analytics only.

  ## What is deliberately not here

  No account, device or install identifier, and nothing that survives from
  one completion to the next. Two Rosaries prayed from the same phone are
  indistinguishable from two prayed by strangers, which is the point: the
  table answers "how many, from where, on what" and cannot be made to
  answer "who".

  `ip_prefix` is a truncated network prefix, never a full address - see
  `LumenViae.Services.Geolocation.anonymize/1`. It is coarse enough that it cannot
  single out a household and specific enough to tell two cities apart.

  `prayed_aloud` says whether the spoken Rosary was on. It is `nil` when
  the client did not say, which is every row from before it existed.

  `time_zone` and `locale` are reported by the client. On iOS both are
  readable without any permission prompt, so nothing here is gated behind a
  dialog the reader has to be talked through.

  Private to `LumenViae.Rosary.Completions`; reach completions through
  `LumenViae.Rosary`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LumenViae.Rosary.MeditationSets.MeditationSet

  @sources ~w(web ios)

  schema "rosary_completions" do
    field :completed_at, :utc_datetime
    field :ip_prefix, :string
    field :city, :string
    field :region, :string
    field :country, :string
    field :country_code, :string
    field :source, :string
    field :time_zone, :string
    field :locale, :string
    field :prayed_aloud, :boolean

    belongs_to :meditation_set, MeditationSet

    timestamps(updated_at: false)
  end

  @doc """
  The surfaces a completion can be reported from.
  """
  def sources, do: @sources

  def changeset(rosary_completion, attrs) do
    rosary_completion
    |> cast(attrs, [
      :meditation_set_id,
      :completed_at,
      :ip_prefix,
      :city,
      :region,
      :country,
      :country_code,
      :source,
      :time_zone,
      :locale,
      :prayed_aloud
    ])
    |> validate_required([:meditation_set_id, :completed_at])
    |> validate_inclusion(:source, @sources)
    # Client-reported strings arrive from a request body and are stored
    # unread by anything that would sanitise them, so they are bounded here
    # rather than trusted to be the short identifiers they are meant to be.
    |> validate_length(:time_zone, max: 64)
    |> validate_length(:locale, max: 32)
    |> foreign_key_constraint(:meditation_set_id)
  end
end
