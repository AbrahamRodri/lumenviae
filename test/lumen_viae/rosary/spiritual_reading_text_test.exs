defmodule LumenViae.Rosary.SpiritualReadingTextTest do
  @moduledoc """
  A book's text as the website reads it, through
  `LumenViae.Rosary.read_spiritual_book!/2`: fetched from Project Gutenberg
  by the server (stubbed here through Req.Test; nothing touches the
  network), cut, and held so it is fetched once. Not async: the cache is
  one table for the whole machine.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias LumenViae.Rosary
  alias LumenViae.Rosary.SpiritualReading.Gutenberg
  alias LumenViae.Rosary.SpiritualReading.Text

  @lawrence File.read!("test/support/fixtures/gutenberg/pg13871.txt")

  setup do
    Text.reset()
    on_exit(&Text.reset/0)
    counter = :counters.new(1, [])
    {:ok, fetches: counter}
  end

  defp serve(counter, answer) do
    Req.Test.stub(Gutenberg, fn conn ->
      :counters.add(counter, 1, 1)

      case answer do
        {:text, text} ->
          assert conn.request_path == "/cache/epub/13871/pg13871.txt"
          Req.Test.text(conn, text)

        {:status, status} ->
          Plug.Conn.send_resp(conn, status, "")

        :down ->
          Req.Test.transport_error(conn, :econnrefused)
      end
    end)
  end

  test "a book is fetched once, cut, and its chapters read by index", %{fetches: fetches} do
    serve(fetches, {:text, @lawrence})

    book = Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    assert book.status == :ok
    assert length(book.contents) == 20
    assert hd(book.contents) == %{id: 0, part: nil, heading: "Preface", title: nil}
    assert book.chapter == nil
    assert book.fingerprint =~ ~r/^[0-9a-f]{8}$/

    chapter =
      Rosary.read_spiritual_book!("practice-of-the-presence-of-god", %{chapter: 1}).chapter

    assert chapter.heading == "First Conversation"
    assert chapter.part == "Conversations"
    assert chapter.paragraphs != []

    assert :counters.get(fetches, 1) == 1
  end

  test "cached_only answers :cold for a book not yet fetched, and fetches nothing",
       %{fetches: fetches} do
    serve(fetches, {:text, @lawrence})

    assert Rosary.read_spiritual_book!("practice-of-the-presence-of-god", %{cached_only: true}) ==
             %{status: :cold}

    assert :counters.get(fetches, 1) == 0

    Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

    assert %{status: :ok} =
             Rosary.read_spiritual_book!("practice-of-the-presence-of-god", %{
               chapter: 0,
               cached_only: true
             })
  end

  test "a chapter or a book the shelf does not have is :not_found", %{fetches: fetches} do
    serve(fetches, {:text, @lawrence})

    assert %{status: :not_found} =
             Rosary.read_spiritual_book!("practice-of-the-presence-of-god", %{chapter: 20})

    assert %{status: :not_found} = Rosary.read_spiritual_book!("no-such-book")
  end

  test "Gutenberg down is :unreachable, and is remembered for a minute", %{fetches: fetches} do
    serve(fetches, :down)

    assert %{status: :unreachable} =
             Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

    assert %{status: :unreachable} =
             Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

    assert :counters.get(fetches, 1) == 1
  end

  test "a non-200 answer is :unreachable", %{fetches: fetches} do
    serve(fetches, {:status, 503})

    assert %{status: :unreachable} =
             Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
  end

  # A text the size of a book that holds no chapter.
  @no_chapters "*** START OF THE PROJECT GUTENBERG EBOOK X ***\n" <>
                 String.duplicate("Nothing here but words, and no heading over them.\n\n", 600)

  test "a text that cuts into no chapters is :unreadable, held for an hour", %{fetches: fetches} do
    serve(fetches, {:text, @no_chapters})
    assert %{status: :unreadable} = Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    assert %{status: :unreadable} = Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    assert :counters.get(fetches, 1) == 1
  end

  describe "the download is the server's, not the visitor's (W1)" do
    test "a caller that stops waiting leaves the download running, and it is stored",
         %{fetches: fetches} do
      gate = self()

      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(fetches, 1, 1)
        send(gate, :asked)

        receive do
          :answer -> Req.Test.text(conn, @lawrence)
        after
          5_000 -> Req.Test.text(conn, @lawrence)
        end
      end)

      # The first visitor's page asks, then goes away mid-download, as a
      # LiveView's start_async task does when its tab closes.
      visitor =
        Task.async(fn -> Rosary.read_spiritual_book!("practice-of-the-presence-of-god") end)

      assert_receive :asked, 2_000
      Task.shutdown(visitor, :brutal_kill)

      # A second visitor waits on the same download rather than starting one.
      second =
        Task.async(fn -> Rosary.read_spiritual_book!("practice-of-the-presence-of-god") end)

      Process.sleep(50)
      stub_owner_answers()
      assert %{status: :ok} = Task.await(second, 5_000)
      assert :counters.get(fetches, 1) == 1
    end
  end

  describe "the deadline" do
    test "a book stored a moment before the deadline is answered, not overwritten",
         %{fetches: fetches} do
      gate = self()

      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(fetches, 1, 1)
        send(gate, :asked)

        receive do
          :answer -> Req.Test.text(conn, @lawrence)
        after
          5_000 -> Req.Test.text(conn, @lawrence)
        end
      end)

      visitor =
        Task.async(fn -> Rosary.read_spiritual_book!("practice-of-the-presence-of-god") end)

      assert_receive :asked, 2_000

      # The download stores the book, then its deadline fires before its
      # answer reaches the cache's owner.
      %{loading: loading, tasks: tasks} = :sys.get_state(Text)
      [{key, _entry}] = Map.to_list(loading)
      [ref] = Map.keys(tasks)
      contents = %{fingerprint: elem(key, 2), chapters: []}
      expires = System.monotonic_time(:millisecond) + 60_000
      :ets.insert(:lumen_viae_spiritual_reading_text, {key, {:ok, contents}, expires})

      send(Text, {:deadline, ref})

      assert %{status: :ok, contents: []} = Task.await(visitor, 5_000)

      assert %{status: :ok} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god", %{
                 cached_only: true
               })
    end
  end

  # The stub's waiting download is answered (it runs in Text's own task,
  # which is no child of this test).
  defp stub_owner_answers do
    for pid <- Task.Supervisor.children(LumenViae.Rosary.SpiritualReading.Fetches),
        do: send(pid, :answer)
  end

  describe "text that is not UTF-8 (W2)" do
    test "a stray byte that is not UTF-8 is read as Latin-1, and the book cut",
         %{fetches: fetches} do
      # One 0xE9 ("é" in Latin-1), which made the parser's patterns raise.
      latin1 = String.replace(@lawrence, "Lorraine", "Lorr" <> <<0xE9>> <> "ne", global: false)
      refute String.valid?(latin1)
      serve(fetches, {:text, latin1})

      assert %{status: :ok, contents: contents} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

      assert length(contents) == 20
    end
  end

  describe "a 200 that is not the book (W3)" do
    test "an HTML page is :unreachable", %{fetches: fetches} do
      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(fetches, 1, 1)
        Req.Test.html(conn, String.duplicate("<p>Access denied</p>", 5_000))
      end)

      assert %{status: :unreachable} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    end

    test "plain text under 50,000 bytes is :unreachable", %{fetches: fetches} do
      Application.put_env(
        :lumen_viae,
        :spiritual_reading,
        Keyword.delete(Application.get_env(:lumen_viae, :spiritual_reading), :minimum_bytes)
      )

      on_exit(fn ->
        Application.put_env(
          :lumen_viae,
          :spiritual_reading,
          Keyword.put(
            Application.get_env(:lumen_viae, :spiritual_reading),
            :minimum_bytes,
            20_000
          )
        )
      end)

      serve(fetches, {:text, binary_part(@lawrence, 0, 49_999)})

      assert %{status: :unreachable} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    end
  end

  describe "redirects and size (W4)" do
    test "a redirect is not followed", %{fetches: fetches} do
      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(fetches, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("location", "https://elsewhere.example/pg13871.txt")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert %{status: :unreachable} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")

      assert :counters.get(fetches, 1) == 1
    end

    test "a body past 5 MB is stopped and counts as unreachable", %{fetches: fetches} do
      serve(fetches, {:text, @lawrence <> String.duplicate("x", 5_000_001)})

      assert %{status: :unreachable} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    end

    test "a size declared past 5 MB is refused", %{fetches: fetches} do
      Req.Test.stub(Gutenberg, fn conn ->
        :counters.add(fetches, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("content-length", "9000000")
        |> Req.Test.text(@lawrence)
      end)

      assert %{status: :unreachable} =
               Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
    end
  end
end
