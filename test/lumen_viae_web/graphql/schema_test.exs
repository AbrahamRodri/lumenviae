defmodule LumenViaeWeb.Graphql.SchemaTest do
  @moduledoc """
  What the GraphQL API exposes, pinned.

  The API reads through actions that already filter to what the public may
  see, and each type lists the relationships it shows. What remains is
  making sure nobody widens it by accident: a relationship added to a
  type's whitelist, a private attribute made public, a resource given a
  query. So the whole schema is committed in `priv/graphql/schema.graphql`
  and must match the running one exactly - any change to what the API
  exposes is a diff in that file, in review, rather than a quiet side
  effect of editing a resource. Regenerate it with:

      mix absinthe.schema.sdl --schema LumenViaeWeb.GraphqlSchema priv/graphql/schema.graphql

  And the columns that must never reach a client are named outright, so a
  regenerated snapshot cannot wave one through.
  """
  use ExUnit.Case, async: true

  @snapshot "priv/graphql/schema.graphql"

  # Field names (as GraphQL spells them) that would leak something private:
  # S3 keys instead of signed URLs, the analytics' network prefix and place,
  # moderation state, raw artwork columns that bypass the publishable gate,
  # narration markup, and the meditation's audio filename. (A completion's
  # source is decided by the server; the input test below pins that.)
  @never_exposed ~w(
    s3Key ipPrefix city region country countryCode timeZone locale
    archivedAt imageKey imageAlt imageLicense imageFocalX imageFocalY
    ttsAnnotations audioUrl authorId mysteryId
  )

  # Types a client must never reach.
  @never_reachable ~w(Narration Author)

  # A completion is reachable only as recordCompletion's answer, and shows
  # exactly what POST /api/completions answers.
  @completion_fields ~w(completedAt id meditationSetId)

  defp sdl, do: Absinthe.Schema.to_sdl(LumenViaeWeb.GraphqlSchema)

  test "the running schema matches the committed snapshot" do
    assert sdl() == File.read!(@snapshot), """
    The GraphQL schema changed. If that is intended, regenerate the snapshot
    and review the diff as a change to the public API:

        mix absinthe.schema.sdl --schema LumenViaeWeb.GraphqlSchema #{@snapshot}
    """
  end

  test "no private column is a field of any type" do
    fields =
      Regex.scan(~r/^\s+([a-zA-Z0-9]+)(?:\(|:)/m, sdl(), capture: :all_but_first)
      |> List.flatten()
      |> MapSet.new()

    leaked = Enum.filter(@never_exposed, &MapSet.member?(fields, &1))
    assert leaked == [], "private fields exposed over GraphQL: #{inspect(leaked)}"
  end

  test "no private resource is a reachable type" do
    types =
      Regex.scan(~r/^type ([A-Za-z0-9]+)/m, sdl(), capture: :all_but_first)
      |> List.flatten()

    reachable = Enum.filter(@never_reachable, &(&1 in types))
    assert reachable == [], "private resources reachable over GraphQL: #{inspect(reachable)}"
  end

  test "a completion shows exactly what the REST response shows" do
    [_, body] = Regex.run(~r/^type Completion \{(.*?)^\}/ms, sdl())

    fields =
      Regex.scan(~r/^  ([a-zA-Z0-9]+):/m, body, capture: :all_but_first)
      |> List.flatten()
      |> Enum.sort()

    assert fields == @completion_fields
  end

  test "recordCompletion takes the set and whether it was prayed aloud, nothing else" do
    [_, body] = Regex.run(~r/^input RecordCompletionInput \{(.*?)^\}/ms, sdl())

    inputs = Regex.scan(~r/^  ([a-zA-Z0-9]+):/m, body, capture: :all_but_first) |> List.flatten()

    assert Enum.sort(inputs) == ["meditationSetId", "prayedAloud"]
  end

  test "the only writes are the ones allowed" do
    mutations =
      case Regex.run(~r/^type RootMutationType \{(.*?)^\}/ms, sdl()) do
        nil -> []
        [_, body] -> Regex.scan(~r/^  ([a-zA-Z0-9]+)/m, body, capture: :all_but_first)
      end
      |> List.flatten()

    assert mutations -- ["recordCompletion"] == []
  end
end
