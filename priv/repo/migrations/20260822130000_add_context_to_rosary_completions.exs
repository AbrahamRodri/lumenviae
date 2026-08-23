defmodule LumenViae.Repo.Migrations.AddContextToRosaryCompletions do
  use Ecto.Migration

  @moduledoc """
  Widens a completion from "which set, and when" to "which set, when, and
  roughly where from".

  The IP column is renamed rather than reused. What is stored there is no
  longer an address but a truncated network prefix, and a column called
  `ip_address` holding something that is not one is the kind of detail that
  is true on the day it ships and misleading a year later.
  """

  def change do
    rename table(:rosary_completions), :ip_address, to: :ip_prefix

    alter table(:rosary_completions) do
      # "web" or "ios". Which surface the Rosary was prayed on, so the two
      # can be read apart instead of summing into one uninterpretable number.
      add :source, :string

      # Reported by the client, not derived from the IP. Both are available
      # without a permission prompt on iOS, and a timezone is a far better
      # signal of habit (praying at six in the morning) than a datacentre
      # geolocation is of place.
      add :time_zone, :string
      add :locale, :string
    end

    create index(:rosary_completions, [:country_code])
    create index(:rosary_completions, [:source])
  end
end
