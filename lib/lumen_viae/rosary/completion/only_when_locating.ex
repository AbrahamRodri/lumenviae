defmodule LumenViae.Rosary.Completion.OnlyWhenLocating do
  @moduledoc """
  Empties the place lookup sweep's read while geolocation is switched off.

  The sweep (the `:locate` trigger's hourly scheduler) would otherwise queue
  a job for every recent placeless completion on a machine where every
  lookup answers nothing without asking - which is every development
  machine, and production with `GEOLOCATION_ENABLED=false`. A job that runs
  only to find nothing is noise in the queue; `Completion.Stamp` skips
  enqueueing for the same reason.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  alias LumenViae.Services.Geolocation

  @impl true
  def prepare(query, _opts, _context) do
    if Geolocation.enabled?(), do: query, else: Ash.Query.filter(query, false)
  end
end
