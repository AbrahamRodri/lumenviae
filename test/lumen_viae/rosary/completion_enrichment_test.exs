defmodule LumenViae.Rosary.CompletionEnrichmentTest do
  @moduledoc """
  The completion is written first and the place arrives afterwards, from a
  background job (the completion's `:locate` trigger). This is the seam
  between the two.

  Oban runs in manual mode under test, so a job only runs when its queue is
  drained, and draining runs it in the test's own process: the Req stub and
  the sandbox both reach it without being shared.

  Not async: the geolocation switch is application config.
  """
  use LumenViae.DataCase, async: false
  use Oban.Testing, repo: LumenViae.Repo

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion
  alias LumenViae.Rosary.Completion.LocateWorker
  alias LumenViae.Services.Geolocation

  setup do
    put_env([
      {:lumen_viae, :geolocation,
       enabled: true, provider: :ipapi_co, req_options: [plug: {Req.Test, Geolocation}]}
    ])

    {:ok, set} =
      Rosary.create_meditation_set(
        %{
          name: "Enrich #{System.unique_integer([:positive])}",
          category: "joyful"
        },
        actor: admin()
      )

    %{set: set}
  end

  # Unique per test, so one test's answer cannot sit in the geolocation
  # cache waiting for another.
  defp an_address do
    n = System.unique_integer([:positive])
    "203.0.#{rem(n, 250)}.#{rem(div(n, 250), 250) + 1}"
  end

  defp dallas(conn) do
    Req.Test.json(conn, %{
      "city" => "Dallas",
      "region" => "Texas",
      "country_name" => "United States",
      "country_code" => "US"
    })
  end

  defp run_lookups, do: Oban.drain_queue(queue: :geolocation)

  test "the place is filled in after the completion is written", %{set: set} do
    Req.Test.stub(Geolocation, &dallas/1)

    {:ok, completion} =
      Rosary.record_completion(set.id, %{source: "web", ip: an_address()})

    # Written immediately, with no place yet: the row does not wait on the
    # lookup, which is the whole point of doing it afterwards.
    assert completion.country == nil
    assert completion.ip_prefix =~ ~r/\.0$/
    assert_enqueued(worker: LocateWorker, queue: :geolocation)

    assert %{success: 1, failure: 0} = run_lookups()

    reloaded = Repo.get(Completion, completion.id)
    assert reloaded.country == "United States"
    assert reloaded.city == "Dallas"
    assert reloaded.region == "Texas"
    assert reloaded.country_code == "US"
    # Enriching must not disturb what was already recorded.
    assert reloaded.source == "web"
    assert reloaded.ip_prefix == completion.ip_prefix
  end

  test "the job carries the completion's id and no part of the address", %{set: set} do
    ip = an_address()
    {:ok, completion} = Rosary.record_completion(set.id, %{ip: ip})

    assert [job] = all_enqueued(worker: LocateWorker)
    assert job.args["primary_key"] == %{"id" => completion.id}

    stored = Jason.encode!(job.args)
    refute stored =~ ip
    refute stored =~ completion.ip_prefix
  end

  test "the provider is asked about the stored prefix, never the full address", %{set: set} do
    test_pid = self()

    Req.Test.stub(Geolocation, fn conn ->
      send(test_pid, {:asked, conn.request_path})
      dallas(conn)
    end)

    ip = an_address()
    {:ok, completion} = Rosary.record_completion(set.id, %{ip: ip})
    run_lookups()

    assert_received {:asked, path}
    assert path == "/#{completion.ip_prefix}/json/"
    refute path =~ ip
  end

  test "a provider that fails is asked again later, and the completion stands", %{set: set} do
    Req.Test.stub(Geolocation, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:ok, completion} = Rosary.record_completion(set.id, %{ip: an_address()})

    # A failure to ask is not an answer: the job fails and Oban retries it.
    assert %{failure: 1, success: 0} = run_lookups()
    assert Repo.get(Completion, completion.id).country == nil

    # The provider is back by the retry, and nothing cached the failure.
    Req.Test.stub(Geolocation, &dallas/1)
    assert %{success: 1} = Oban.drain_queue(queue: :geolocation, with_scheduled: true)
    assert Repo.get(Completion, completion.id).country == "United States"
  end

  test "a provider that answers it cannot place the address is believed", %{set: set} do
    Req.Test.stub(Geolocation, fn conn ->
      Req.Test.json(conn, %{"error" => true, "reason" => "Reserved IP Address"})
    end)

    assert {:ok, completion} = Rosary.record_completion(set.id, %{ip: an_address()})
    assert %{success: 1, failure: 0} = run_lookups()
    assert Repo.get(Completion, completion.id).country == nil
  end

  test "a completion that already has a place is not looked up again", %{set: set} do
    test_pid = self()

    Req.Test.stub(Geolocation, fn conn ->
      send(test_pid, :asked)
      dallas(conn)
    end)

    {:ok, completion} = Rosary.record_completion(set.id, %{ip: an_address()})

    completion
    |> Ash.Changeset.for_update(:place, %{country: "Philippines", country_code: "PH"})
    |> Ash.update!(actor: LumenViae.Test.Admins.admin())

    assert %{cancelled: 1} = run_lookups()
    refute_received :asked
    assert Repo.get(Completion, completion.id).country_code == "PH"
  end

  test "a private address schedules nothing, so it is never sent anywhere", %{set: set} do
    {:ok, _} = Rosary.record_completion(set.id, %{ip: "192.168.1.50"})

    refute_enqueued(worker: LocateWorker)
  end

  test "with geolocation switched off nothing is scheduled", %{set: set} do
    put_env([{:lumen_viae, :geolocation, enabled: false}])

    {:ok, _} = Rosary.record_completion(set.id, %{ip: an_address()})

    refute_enqueued(worker: LocateWorker)
  end
end
