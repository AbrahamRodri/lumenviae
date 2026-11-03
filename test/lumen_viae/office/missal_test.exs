defmodule LumenViae.Office.MissalTest do
  @moduledoc """
  The Daily Missal's fetch from Missale Meum, through
  `LumenViae.Office.fetch_mass/1`, `fetch_missal_calendar/1` and
  `fetch_order_of_mass/0`: what is read from the saved answers, and how
  the server keeps from hammering Missale Meum (one fetch per cold key,
  owned by no caller; failures held; a block page, a redirect or a body
  past the cap counted as a failure). Req.Test stands in for the wire, and
  each test has an Office cache of its own.
  """
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias LumenViae.Office
  alias LumenViae.Office.MissaleMeum

  @fixtures Path.expand("../../support/fixtures/missale_meum", __DIR__)

  setup do
    LumenViae.Office.Cache.isolate()
    :ok
  end

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  # Answers with `body` as JSON and counts the requests.
  defp stub_json(body) do
    calls = :counters.new(1, [])

    Req.Test.stub(MissaleMeum, fn conn ->
      :counters.add(calls, 1, 1)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end)

    calls
  end

  defp count(calls), do: :counters.get(calls, 1)

  describe "reading" do
    test "a day's Masses, three on All Souls, with their parts as pairs" do
      stub_json(fixture("proper_2026-11-02.json"))

      assert {:ok, [first, second, third]} = Office.fetch_mass(~D[2026-11-02])
      assert first.title == "Commemoration of All Souls"
      assert second.title =~ "Second Mass"
      assert third.title =~ "Third Mass"
      assert first.rank == 1
      assert first.colors == ["b"]
      assert first.description == nil
      assert first.tempora =~ "after XXIII Sunday after Pentecost"

      assert Enum.map(first.sections, & &1.id) ==
               ~w(Introitus Oratio Lectio Graduale Sequentia Evangelium Offertorium Secreta Prefatio Communio Postcommunio)

      [[english, latin] | _] = hd(first.sections).body
      assert english =~ "Eternal rest"
      assert latin =~ "Réquiem ætérnam"
    end

    test "what else is remembered" do
      stub_json(fixture("proper_2026-11-04.json"))

      assert {:ok, [mass]} = Office.fetch_mass(~D[2026-11-04])
      assert mass.title == "St. Charles Borromeo"
      assert mass.commemorations == ["Sts. Vitalis and Agricola, Martyrs"]
    end

    test "a year's calendar, by date" do
      stub_json(fixture("calendar_2026.json"))

      assert {:ok, days} = Office.fetch_missal_calendar(2026)
      assert map_size(days) == 365
      assert days[~D[2026-11-04]].title == "St. Charles Borromeo"
      assert days[~D[2026-11-04]].colors == ["w"]
      assert days[~D[2026-11-04]].rank == 3
    end

    test "the Order of Mass, rubrics as single texts" do
      stub_json(fixture("ordo.json"))

      assert {:ok, sections} = Office.fetch_order_of_mass()
      assert hd(sections).label == "Asperges"
      assert List.last(sections).label == "Prayers ordered by the pope Leo XIII"
      assert Enum.any?(hd(sections).body, &match?([_rubric], &1))
    end

    test "is cached: a second ask fetches nothing" do
      calls = stub_json(fixture("proper_2026-11-04.json"))

      assert {:ok, _} = Office.fetch_mass(~D[2026-11-04])
      assert {:ok, _} = Office.fetch_mass(~D[2026-11-04])
      assert count(calls) == 1
    end
  end

  describe "failures" do
    test "Missale Meum down is said as unavailable, and held" do
      calls = :counters.new(1, [])

      Req.Test.stub(MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      # Any other key is held too while Missale Meum is failing.
      assert {:error, :missal_unavailable} = Office.fetch_missal_calendar(2026)
      assert {:error, :missal_unavailable} = Office.fetch_order_of_mass()
      assert count(calls) == 1
    end

    test "an HTML block page with a 200 is a failure, held, never a crash" do
      calls = :counters.new(1, [])

      Req.Test.stub(MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)
        Req.Test.html(conn, "<html><body>Just a moment...</body></html>")
      end)

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert count(calls) == 1
    end

    test "JSON of another shape is a failure" do
      stub_json(~s({"detail": "Not Found"}))
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
    end

    test "a non-200 is a failure" do
      Req.Test.stub(MissaleMeum, &Plug.Conn.send_resp(&1, 503, "busy"))
      assert {:error, :missal_unavailable} = Office.fetch_order_of_mass()
    end

    test "a redirect is not followed" do
      calls = :counters.new(1, [])

      Req.Test.stub(MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("location", "https://elsewhere.example/ordo")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, :missal_unavailable} = Office.fetch_order_of_mass()
      assert count(calls) == 1
    end

    test "a body past the cap is dropped" do
      big = ~s([") <> String.duplicate("a", MissaleMeum.max_body_bytes()) <> ~s("])
      stub_json(big)
      assert {:error, :missal_unavailable} = Office.fetch_order_of_mass()
    end
  end

  describe "one fetch, owned by no caller" do
    test "concurrent misses share one fetch" do
      calls = :counters.new(1, [])
      body = fixture("proper_2026-11-04.json")

      Req.Test.stub(MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)
        Process.sleep(150)
        Req.Test.json(conn, Jason.decode!(body))
      end)

      results =
        1..8
        |> Enum.map(fn _ -> Task.async(fn -> Office.fetch_mass(~D[2026-11-04]) end) end)
        |> Task.await_many(5_000)

      assert Enum.all?(results, &match?({:ok, [%{title: "St. Charles Borromeo"}]}, &1))
      assert count(calls) == 1
    end

    test "a caller that goes away does not abort the fetch: it is stored for the next" do
      calls = :counters.new(1, [])
      body = fixture("proper_2026-11-04.json")
      test = self()

      Req.Test.stub(MissaleMeum, fn conn ->
        :counters.add(calls, 1, 1)
        send(test, {:fetching, self()})

        receive do
          :go -> Req.Test.json(conn, Jason.decode!(body))
        end
      end)

      # A visitor's page, as LiveView's tasks are: its caller is the test.
      caller =
        spawn(fn ->
          Process.put(:"$callers", [test])
          Office.fetch_mass(~D[2026-11-04])
        end)

      assert_receive {:fetching, fetcher}, 2_000
      Process.exit(caller, :kill)
      send(fetcher, :go)

      assert eventually(fn -> match?({:ok, _}, Office.fetch_mass(~D[2026-11-04])) end)
      assert count(calls) == 1
    end
  end

  describe "bounds (W1)" do
    test "at most four fetches at once; past that, unavailable with nothing held" do
      test = self()

      Req.Test.stub(MissaleMeum, fn conn ->
        send(test, {:fetching, self()})

        receive do
          :go -> Req.Test.json(conn, [])
        end
      end)

      waiting =
        for day <- 1..4 do
          Task.async(fn -> Office.fetch_mass(Date.new!(2026, 11, day)) end)
        end

      fetchers =
        for _ <- 1..4 do
          assert_receive {:fetching, pid}, 2_000
          pid
        end

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-05])

      Enum.each(fetchers, &send(&1, :go))
      assert Enum.all?(Task.await_many(waiting), &match?({:ok, []}, &1))

      # Nothing was held: the fifth day is asked for as soon as there is room.
      Req.Test.stub(MissaleMeum, &Req.Test.json(&1, []))
      assert {:ok, []} = Office.fetch_mass(~D[2026-11-05])
    end

    test "at most sixty cold fetches a minute; past that, unavailable with nothing held" do
      calls = stub_json("[]")

      for day <- 0..59 do
        assert {:ok, []} = Office.fetch_mass(Date.add(~D[2026-01-01], day))
      end

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-06-01])
      assert count(calls) == 60
      # What is cached is still served.
      assert {:ok, []} = Office.fetch_mass(~D[2026-01-01])
    end

    test "a day far from today, or a year far from this one, is kept an hour" do
      today = ~D[2026-11-03]
      hour = :timer.hours(1)

      assert LumenViae.Office.Missal.ttl({:missal, :proper, ~D[2026-11-20]}, today) == nil
      assert LumenViae.Office.Missal.ttl({:missal, :proper, ~D[2026-12-15]}, today) == nil
      assert LumenViae.Office.Missal.ttl({:missal, :proper, ~D[2027-03-01]}, today) == hour
      assert LumenViae.Office.Missal.ttl({:missal, :proper, ~D[1700-01-01]}, today) == hour
      assert LumenViae.Office.Missal.ttl({:missal, :calendar, 2027}, today) == nil
      assert LumenViae.Office.Missal.ttl({:missal, :calendar, 2030}, today) == hour
      assert LumenViae.Office.Missal.ttl({:missal, :ordo}, today) == nil
    end
  end

  describe "which failures close every key (W2)" do
    test "a 404 or an unreadable answer holds only its own key" do
      Req.Test.stub(MissaleMeum, fn conn ->
        case conn.request_path do
          "/en/api/v5/proper/2026-11-04" -> Plug.Conn.send_resp(conn, 404, "{}")
          "/en/api/v5/proper/2026-11-05" -> Req.Test.html(conn, "<html>blocked</html>")
          _other -> Req.Test.json(conn, [])
        end
      end)

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert {:ok, []} = Office.fetch_mass(~D[2026-11-06])
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-05])
      assert {:ok, []} = Office.fetch_mass(~D[2026-11-07])
    end

    test "a 5xx closes every key for a while" do
      Req.Test.stub(MissaleMeum, fn conn ->
        case conn.request_path do
          "/en/api/v5/proper/2026-11-04" -> Plug.Conn.send_resp(conn, 502, "")
          _other -> Req.Test.json(conn, [])
        end
      end)

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-06])
    end
  end

  describe "the deadline" do
    test "a fetch past it is stopped, counted as Missale Meum failing, and held" do
      Process.put(:missal_deadline_ms, 100)

      Req.Test.stub(MissaleMeum, fn conn ->
        Process.sleep(1_000)
        Req.Test.json(conn, [])
      end)

      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-04])
      assert {:error, :missal_unavailable} = Office.fetch_mass(~D[2026-11-06])
    end

    test "a value stored a moment before the deadline is answered, with no failure held" do
      test = self()

      Req.Test.stub(MissaleMeum, fn conn ->
        send(test, :fetching)
        Process.sleep(1_000)
        Req.Test.json(conn, [])
      end)

      stored = [%{title: "Stored"}]

      caller =
        Task.async(fn ->
          Process.put(:missal_deadline_ms, 150)
          Office.fetch_mass(~D[2026-11-04])
        end)

      assert_receive :fetching, 2_000
      # The task's store, as it lands in the instant before the deadline.
      LumenViae.Office.Cache.put({:missal, :proper, ~D[2026-11-04]}, stored)

      assert {:ok, ^stored} = Task.await(caller)
      Req.Test.stub(MissaleMeum, &Req.Test.json(&1, []))
      assert {:ok, []} = Office.fetch_mass(~D[2026-11-06])
    end
  end

  defp eventually(fun, tries \\ 50) do
    cond do
      fun.() -> true
      tries == 0 -> false
      true -> Process.sleep(20) && eventually(fun, tries - 1)
    end
  end
end
