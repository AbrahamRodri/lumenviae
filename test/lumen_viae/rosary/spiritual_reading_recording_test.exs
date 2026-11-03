defmodule LumenViae.Rosary.SpiritualReadingRecordingTest do
  @moduledoc """
  A book's LibriVox recording as the website plays it, through
  `LumenViae.Rosary.read_spiritual_recording!/2`: its track list fetched
  from LibriVox by the server and lined up with the chapters, and how the
  server keeps from hammering LibriVox (one fetch per book, owned by no
  caller; failures held, a book's own or, when LibriVox itself fails,
  every book's; a block page, a redirect or a body past the cap counted a
  failure; a deadline; at most two fetches at once and twelve a minute).
  Req.Test stands in for LibriVox and Gutenberg; nothing touches the
  network. Not async: the books' text is one table for the machine.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias LumenViae.Rosary
  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.LibriVox
  alias LumenViae.Rosary.SpiritualReading.Recording
  alias LumenViae.Rosary.SpiritualReading.Text

  @lawrence "practice-of-the-presence-of-god"
  @therese "story-of-a-soul"
  @gutenberg Path.expand("../../support/fixtures/gutenberg", __DIR__)
  @librivox Path.expand("../../support/fixtures/librivox", __DIR__)

  setup do
    Text.reset()
    on_exit(&Text.reset/0)
    Recording.isolate()

    texts = %{"13871" => "pg13871.txt", "16772" => "pg16772-excerpt.txt"}

    Req.Test.stub(Gutenberg, fn conn ->
      [_cache, _epub, id | _rest] = conn.path_info
      Req.Test.text(conn, File.read!(Path.join(@gutenberg, Map.fetch!(texts, id))))
    end)

    :ok
  end

  defp feed(id), do: File.read!(Path.join(@librivox, "feed-#{id}.json"))

  # Answers each book's feed (or `answer`) and counts the requests.
  defp stub_librivox(answer \\ :feed) do
    calls = :counters.new(1, [])

    Req.Test.stub(LibriVox, fn conn ->
      :counters.add(calls, 1, 1)
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.request_path == "/api/feed/audiobooks/"
      assert %{"extended" => "1", "format" => "json", "id" => id} = conn.query_params

      case answer do
        :feed -> json(conn, feed(id))
        fun when is_function(fun, 2) -> fun.(conn, id)
      end
    end)

    calls
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, body)
  end

  defp count(calls), do: :counters.get(calls, 1)

  defp recording(book_id, args \\ %{}), do: Rosary.read_spiritual_recording!(book_id, args)

  describe "reading" do
    test "the tracks, fetched once, lined up with the chapters" do
      calls = stub_librivox()

      recording = recording(@lawrence)
      assert recording.status == :ok
      assert length(recording.tracks) == 19
      assert length(recording.chapters) == 20

      first = hd(recording.tracks)
      assert first.title == "First Conversation"
      assert first.seconds == 242
      assert first.chapter == 1

      assert first.url ==
               "https://www.archive.org/download/presence_of_god_librivox/practiceofpresence_01_lawrence_64kb.mp3"

      # The preface has no track; the first conversation is read whole by
      # the first.
      assert Enum.at(recording.chapters, 0) == nil
      assert Enum.at(recording.chapters, 1) == %{track: 0, from: 1, whole?: true}

      assert recording(@lawrence).status == :ok
      assert count(calls) == 1
    end

    test "a book without a recording has none, and an unknown book is not found" do
      calls = stub_librivox()
      assert recording("imitation-of-christ").status == :none
      assert recording("no-such-book").status == :not_found
      assert count(calls) == 0
    end

    test "with cached_only, a list this machine has not fetched is cold, and nothing is asked" do
      calls = stub_librivox()
      Rosary.read_spiritual_book!(@lawrence)

      assert recording(@lawrence, %{cached_only: true}).status == :cold
      assert count(calls) == 0
      assert recording(@lawrence).status == :ok
      assert recording(@lawrence, %{cached_only: true}).status == :ok
    end

    test "only tracks on the Internet Archive are kept, over https" do
      stub_librivox(fn conn, _id ->
        json(
          conn,
          Jason.encode!(%{
            "books" => [
              %{
                "sections" => [
                  %{"id" => "1", "title" => "A", "listen_url" => "http://www.archive.org/a.mp3"},
                  %{"id" => "2", "title" => "B", "listen_url" => "https://evil.example/b.mp3"},
                  %{"id" => "3", "title" => "C", "listen_url" => "javascript:alert(1)"},
                  %{"id" => "4", "title" => "D", "listen_url" => ""},
                  %{
                    "id" => "5",
                    "title" => "E",
                    "listen_url" => "https://ia800.us.archive.org/e.mp3"
                  }
                ]
              }
            ]
          })
        )
      end)

      recording = recording(@lawrence)

      assert Enum.map(recording.tracks, & &1.url) == [
               "https://www.archive.org/a.mp3",
               "https://ia800.us.archive.org/e.mp3"
             ]

      # A track that can't be played leaves a hole, so nothing is lined up
      # with a chapter it might not read.
      assert Enum.all?(recording.chapters, &is_nil/1)
      assert Enum.all?(recording.tracks, &is_nil(&1.chapter))
    end

    test "a host with a backslash, odd characters or another port is not the Archive" do
      stub_librivox(fn conn, _id ->
        sections =
          [
            "https://evil.com\\.archive.org/x.mp3",
            "https://evil.com%2F.archive.org/x.mp3",
            "https://www.archive.org:8443/x.mp3",
            "HTTPS://WWW.Archive.org/ok.mp3"
          ]
          |> Enum.with_index(1)
          |> Enum.map(fn {url, i} -> %{"id" => "#{i}", "title" => "T", "listen_url" => url} end)

        json(conn, Jason.encode!(%{"books" => [%{"sections" => sections}]}))
      end)

      assert Enum.map(recording(@lawrence).tracks, & &1.url) == [
               "HTTPS://WWW.Archive.org/ok.mp3"
             ]
    end

    test "a feed that trips the alignment leaves the recording unavailable, not a crash" do
      stub_librivox(fn conn, _id ->
        sections =
          for {title, i} <- Enum.with_index(["Chapter 1 Part \u0662", "Chapter 1 pt. \uFF17"], 1) do
            %{
              "id" => "#{i}",
              "title" => title,
              "listen_url" => "https://www.archive.org/#{i}.mp3"
            }
          end

        json(conn, Jason.encode!(%{"books" => [%{"sections" => sections}]}))
      end)

      assert recording(@therese).status == :ok
    end
  end

  describe "one fetch per book, owned by no caller" do
    test "callers at once share one fetch" do
      test = self()

      calls =
        stub_librivox(fn conn, id ->
          send(test, :fetching)
          Process.sleep(200)
          json(conn, feed(id))
        end)

      Rosary.read_spiritual_book!(@lawrence)
      callers = for _ <- 1..5, do: Task.async(fn -> recording(@lawrence) end)

      assert Enum.all?(Task.await_many(callers), &(&1.status == :ok))
      assert count(calls) == 1
    end

    test "a caller that goes away takes nothing with it" do
      test = self()

      calls =
        stub_librivox(fn conn, id ->
          send(test, :fetching)
          Process.sleep(200)
          json(conn, feed(id))
        end)

      Rosary.read_spiritual_book!(@lawrence)
      {:ok, caller} = Task.start(fn -> recording(@lawrence) end)
      assert_receive :fetching, 2_000
      Process.exit(caller, :kill)

      assert recording(@lawrence).status == :ok
      assert count(calls) == 1
    end
  end

  describe "failures are held" do
    test "a 200 that is not the track list is unavailable, and that book is not asked again" do
      calls =
        stub_librivox(fn conn, id ->
          if id == "564",
            do: Req.Test.html(conn, "<html>Just a moment...</html>"),
            else: json(conn, feed(id))
        end)

      assert recording(@lawrence).status == :unavailable
      assert recording(@lawrence).status == :unavailable
      assert count(calls) == 1

      # Another book is still asked for: the failure was this book's.
      assert recording(@therese).status == :ok
      assert count(calls) == 2
    end

    test "JSON of another shape, or a book with no playable tracks, is unavailable and held" do
      for body <- [
            ~s({"error": "Audiobooks could not be found"}),
            ~s({"books": [{"sections": []}]})
          ] do
        Recording.isolate()
        calls = stub_librivox(fn conn, _id -> json(conn, body) end)

        assert recording(@lawrence).status == :unavailable
        assert recording(@lawrence).status == :unavailable
        assert count(calls) == 1
      end
    end

    test "a 404 holds only its own book" do
      calls =
        stub_librivox(fn conn, id ->
          if id == "564", do: Plug.Conn.send_resp(conn, 404, ""), else: json(conn, feed(id))
        end)

      assert recording(@lawrence).status == :unavailable
      assert recording(@therese).status == :ok
      assert count(calls) == 2
    end

    test "LibriVox down or failing (5xx) closes every book for a while" do
      for answer <- [
            &Req.Test.transport_error(&1, :econnrefused),
            &Plug.Conn.send_resp(&1, 503, "")
          ] do
        Recording.isolate()
        calls = stub_librivox(fn conn, _id -> answer.(conn) end)

        assert recording(@lawrence).status == :unavailable
        assert recording(@therese).status == :unavailable
        assert count(calls) == 1
      end
    end

    test "a redirect is never followed" do
      calls =
        stub_librivox(fn conn, _id ->
          conn
          |> Plug.Conn.put_resp_header("location", "https://elsewhere.example/feed.json")
          |> Plug.Conn.send_resp(302, "")
        end)

      assert recording(@lawrence).status == :unavailable
      assert count(calls) == 1
    end

    test "a body past the cap is stopped there, and unavailable" do
      big = String.duplicate(" ", LibriVox.max_body_bytes() + 1)
      calls = stub_librivox(fn conn, id -> json(conn, feed(id) <> big) end)

      assert recording(@lawrence).status == :unavailable
      assert count(calls) == 1
    end
  end

  describe "the deadline" do
    test "a fetch past it is stopped, counted as LibriVox failing, and held" do
      Process.put(:librivox_deadline_ms, 100)

      calls =
        stub_librivox(fn conn, id ->
          Process.sleep(1_000)
          json(conn, feed(id))
        end)

      Rosary.read_spiritual_book!(@lawrence)
      assert recording(@lawrence).status == :unavailable
      assert recording(@therese).status == :unavailable
      assert count(calls) == 1
    end

    test "tracks stored a moment before the deadline are answered, with no failure held" do
      test = self()

      stub_librivox(fn conn, id ->
        send(test, :fetching)
        Process.sleep(1_000)
        json(conn, feed(id))
      end)

      Rosary.read_spiritual_book!(@lawrence)
      stored = [%{id: "1", title: "Stored", url: "https://www.archive.org/s.mp3", seconds: 60}]

      caller =
        Task.async(fn ->
          Process.put(:librivox_deadline_ms, 150)
          recording(@lawrence)
        end)

      assert_receive :fetching, 2_000
      # The task's store, as it lands in the instant before the deadline.
      Recording.put_tracks(564, stored)

      assert %{status: :ok, tracks: [%{title: "Stored"}]} = Task.await(caller)
      assert {:ok, ^stored} = Recording.tracks(%{librivox_id: 564})
    end
  end

  describe "the bounds" do
    test "at most two fetches at once; past that, unavailable with nothing held" do
      test = self()

      stub_librivox(fn conn, id ->
        send(test, {:fetching, self()})

        receive do
          :go -> json(conn, feed(id))
        end
      end)

      Rosary.read_spiritual_book!(@lawrence)
      Rosary.read_spiritual_book!(@therese)

      waiting = [
        Task.async(fn -> Recording.tracks(%{librivox_id: 564}) end),
        Task.async(fn -> Recording.tracks(%{librivox_id: 8021}) end)
      ]

      fetchers =
        for _ <- 1..2 do
          assert_receive {:fetching, pid}, 2_000
          pid
        end

      assert {:error, :unavailable} = Recording.tracks(%{librivox_id: 2601})

      Enum.each(fetchers, &send(&1, :go))
      assert Enum.all?(Task.await_many(waiting), &match?({:ok, [_ | _]}, &1))

      # Nothing was held: the third is asked for as soon as there is room.
      stub_librivox()
      assert {:ok, [_ | _]} = Recording.tracks(%{librivox_id: 2601})
    end

    test "at most twelve cold fetches a minute; past that, unavailable with nothing held" do
      calls = stub_librivox(fn conn, _id -> Plug.Conn.send_resp(conn, 404, "") end)

      # Each fetch fails and is held under its own number, so twelve
      # different numbers spend the minute's budget.
      for id <- 1..12, do: assert({:error, :unavailable} = Recording.tracks(%{librivox_id: id}))
      assert count(calls) == 12

      stub_librivox()
      assert {:error, :unavailable} = Recording.tracks(%{librivox_id: 564})
      Recording.isolate()
      assert {:ok, _tracks} = Recording.tracks(%{librivox_id: 564})
    end
  end
end
