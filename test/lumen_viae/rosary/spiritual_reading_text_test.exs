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
          Plug.Conn.send_resp(conn, 200, text)

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

  test "a text that cuts into no chapters is :unreadable", %{fetches: fetches} do
    serve(fetches, {:text, "*** START OF THE PROJECT GUTENBERG EBOOK X ***\nNothing here.\n"})
    assert %{status: :unreadable} = Rosary.read_spiritual_book!("practice-of-the-presence-of-god")
  end
end
