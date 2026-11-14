defmodule LumenViae.Rosary.StraySpaceMigrationTest do
  @moduledoc """
  `20261106231000_close_stray_spaces_before_punctuation.exs` (content audit
  NIT 1): a space before a comma, semicolon, colon or full stop is closed
  up, a mark run into the next word gets its space after it, an ellipsis
  and a meditation with pause annotations are left alone, running it
  twice changes nothing more, and down puts every row back.
  """
  use LumenViae.DataCase, async: false

  alias LumenViae.Repo
  alias LumenViae.Rosary

  @path "priv/repo/migrations/20261106231000_close_stray_spaces_before_punctuation.exs"

  # The migration's SQL as Postgres receives it: its `execute` heredocs
  # with `@where` put in and Elixir's escaped backslashes undone.
  defp statements(part) do
    source = File.read!(@path)
    [_, where] = Regex.run(~r/@where """\n(.*?)\n\s*"""/s, source)
    [up, down] = String.split(source, "def down do")
    body = if part == :up, do: up, else: down

    for [_, sql] <- Regex.scan(~r/execute """\n(.*?)\n\s*"""/s, body) do
      sql |> String.replace("\#{@where}", where) |> String.replace("\\\\", "\\")
    end
  end

  # The test database has run every migration already, so its (empty)
  # backup table exists: drop it inside this test's transaction first.
  defp run(:up) do
    Repo.query!("DROP TABLE IF EXISTS meditation_content_before_20261106")
    for sql <- statements(:up), do: Repo.query!(sql)
    :ok
  end

  defp run(:down) do
    for sql <- statements(:down), do: Repo.query!(sql)
    :ok
  end

  defp meditation(content, extra \\ %{}) do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "M #{System.unique_integer([:positive])}",
          category: "sorrowful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(Map.merge(%{content: content, mystery_id: mystery.id}, extra),
        actor: admin()
      )

    meditation
  end

  defp content(id) do
    %{rows: [[content]]} = Repo.query!("SELECT content FROM meditations WHERE id = $1", [id])
    content
  end

  test "closes stray spaces, leaves ellipses and annotated text alone, and down undoes it" do
    stray = meditation("Our Lord , though guilty ; said to His enemies . Evil was come ,brought.")
    ellipsis = meditation("He waited ... and then spoke .")
    clean = meditation("Nothing to change here, at all.")

    annotated =
      meditation("A pause , kept.", %{
        tts_annotations: [%{"type" => "pause", "at" => 3, "ms" => 500}]
      })

    run(:up)

    assert content(stray.id) ==
             "Our Lord, though guilty; said to His enemies. Evil was come, brought."

    assert content(ellipsis.id) == "He waited ... and then spoke."
    assert content(clean.id) == "Nothing to change here, at all."
    assert content(annotated.id) == "A pause , kept."

    # Running the update again finds nothing more to change.
    [_create, update] = statements(:up)
    Repo.query!(update)

    assert content(stray.id) ==
             "Our Lord, though guilty; said to His enemies. Evil was come, brought."

    run(:down)

    assert content(stray.id) ==
             "Our Lord , though guilty ; said to His enemies . Evil was come ,brought."

    assert content(ellipsis.id) == "He waited ... and then spoke ."
  end
end
