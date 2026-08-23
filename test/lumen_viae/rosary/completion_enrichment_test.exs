defmodule LumenViae.Rosary.CompletionEnrichmentTest do
  @moduledoc """
  The completion is written first and the place arrives afterwards, from a
  background task. This is the seam between the two.

  Not async: it needs the shared sandbox so the task can reach the database,
  and a shared Req stub so it can reach the stubbed provider.
  """
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completions.Completion
  alias LumenViae.Services.Geolocation

  setup do
    put_env([
      {:lumen_viae, :geolocation,
       enabled: true, provider: :ipapi_co, req_options: [plug: {Req.Test, Geolocation}]}
    ])

    Req.Test.set_req_test_to_shared()
    on_exit(fn -> Req.Test.set_req_test_to_private(self()) end)

    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Enrich #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    %{set: set}
  end

  defp an_address do
    n = System.unique_integer([:positive])
    "203.0.#{rem(n, 250)}.#{rem(div(n, 250), 250)}"
  end

  # The place arrives out of band, so the assertion has to wait for it
  # rather than read the row once and conclude it never came.
  defp eventually(fun, attempts \\ 100) do
    case fun.() do
      nil when attempts > 0 ->
        Process.sleep(10)
        eventually(fun, attempts - 1)

      result ->
        result
    end
  end

  test "the place is filled in after the completion is written", %{set: set} do
    Req.Test.stub(Geolocation, fn conn ->
      Req.Test.json(conn, %{
        "city" => "Dallas",
        "region" => "Texas",
        "country_name" => "United States",
        "country_code" => "US"
      })
    end)

    {:ok, completion} =
      Rosary.record_completion(set.id, %{source: "web", ip: an_address()})

    # Written immediately, with no place yet: the row does not wait on the
    # lookup, which is the whole point of doing it afterwards.
    assert completion.country == nil
    assert completion.ip_prefix =~ ~r/\.0$/

    placed = eventually(fn -> Repo.get(Completion, completion.id).country end)

    assert placed == "United States"

    reloaded = Repo.get(Completion, completion.id)
    assert reloaded.city == "Dallas"
    assert reloaded.region == "Texas"
    assert reloaded.country_code == "US"
    # Enriching must not disturb what was already recorded.
    assert reloaded.source == "web"
    assert reloaded.ip_prefix == completion.ip_prefix
  end

  test "a completion survives a provider that fails", %{set: set} do
    Req.Test.stub(Geolocation, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:ok, completion} = Rosary.record_completion(set.id, %{ip: an_address()})

    Process.sleep(50)

    reloaded = Repo.get(Completion, completion.id)
    assert reloaded.id == completion.id
    assert reloaded.country == nil
  end

  test "a private address is never sent to the provider", %{set: set} do
    test_pid = self()

    Req.Test.stub(Geolocation, fn conn ->
      send(test_pid, :asked)
      Req.Test.json(conn, %{"country_code" => "US", "country_name" => "United States"})
    end)

    {:ok, _} = Rosary.record_completion(set.id, %{ip: "192.168.1.50"})

    Process.sleep(50)

    refute_received :asked
  end
end
