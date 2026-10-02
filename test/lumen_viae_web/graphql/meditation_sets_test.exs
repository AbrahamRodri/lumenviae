defmodule LumenViaeWeb.Graphql.MeditationSetsTest do
  @moduledoc """
  `visibleMeditationSets` and `meditationSet` over GraphQL, held to what
  the REST endpoints serve: the same sets, the same order, the same
  bylines and artwork, meditations in prayer order, and a hidden set
  absent from the list and not found by id.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  @expiry ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  @list_query """
  query Sets($category: String) {
    visibleMeditationSets(category: $category) {
      id name category description labels author source
      artwork {
        url alignment focalX focalY width height alt
        attribution { title artist year sourceUrl license }
      }
    }
  }
  """

  @detail_query """
  query Set($id: ID!, $voice: String) {
    meditationSet(id: $id) {
      id name category author source
      setMemberships {
        order
        meditation {
          id title content author source
          mystery { id name category order description scriptureReference }
          narratedVoices
          narrations { voice audio { url expiresAt } }
          narration(preferring: $voice) { voice audio { url expiresAt } }
        }
      }
    }
  }
  """

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    :ok
  end

  # A set the public can see: it has a meditation. An empty set is hidden.
  defp create_set(attrs) do
    attrs |> create_empty_set() |> LumenViae.Test.Sets.with_meditation()
  end

  # For a test that fills the set itself.
  defp create_empty_set(attrs) do
    defaults = %{name: "GraphQL Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "GraphQL Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: 100 + rem(System.unique_integer([:positive]), 100_000),
          days_prayed: "Monday, Saturday",
          scripture_reference: "Luke 1:26-38"
        },
        actor: admin()
      )

    mystery
  end

  defp create_meditation(mystery, attrs) do
    {:ok, meditation} =
      Rosary.create_meditation(Map.merge(%{content: "Text", mystery_id: mystery.id}, attrs),
        actor: admin()
      )

    meditation
  end

  defp collect_ids(%{} = map) do
    Enum.flat_map(map, fn
      {key, value} when key in ["id", "meditationId", "meditationSetId"] -> [value]
      {_key, value} -> collect_ids(value)
    end)
  end

  defp collect_ids(list) when is_list(list), do: Enum.flat_map(list, &collect_ids/1)
  defp collect_ids(_scalar), do: []

  defp rest_list(conn, category) do
    conn
    |> get("/api/meditation-sets?category=#{category}")
    |> json_response(200)
    |> Map.fetch!("data")
  end

  describe "visibleMeditationSets" do
    test "lists the same sets as REST, in the same order", %{conn: conn} do
      a = create_set(%{name: "A", category: "seven_sorrows"})
      _b = create_set(%{name: "B", category: "seven_sorrows"})
      c = create_set(%{name: "C", category: "seven_sorrows"})
      # Updated after the others, so heap order would put it last.
      {:ok, _} = Rosary.update_meditation_set(a, %{description: "Edited"}, actor: admin())
      _other = create_set(%{name: "Elsewhere", category: "glorious"})

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "seven_sorrows"})

      rest = rest_list(conn, "seven_sorrows")

      assert Enum.map(sets, & &1["id"]) == Enum.map(rest, &to_string(&1["id"]))
      assert Enum.all?(sets, &(&1["category"] == "seven_sorrows"))
      assert List.first(sets)["id"] == to_string(a.id)
      assert List.last(sets)["id"] == to_string(c.id)
    end

    test "leaves out a set hidden by an archived meditation", %{conn: conn} do
      mystery = create_mystery()
      shown = create_set(%{name: "Shown", category: "luminous"})
      hidden = create_empty_set(%{name: "Hidden", category: "luminous"})
      archived = create_meditation(mystery, %{content: "Withdrawn"})
      {:ok, _} = Rosary.add_meditation_to_set(hidden.id, archived.id, 1, actor: admin())
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "luminous"})

      ids = Enum.map(sets, & &1["id"])
      assert to_string(shown.id) in ids
      refute to_string(hidden.id) in ids
    end

    # A set between being created and being given its first meditation has
    # nothing to pray, and is hidden exactly as a withdrawn one is.
    test "leaves out a set with no meditations, and answers null for it by id", %{conn: conn} do
      shown = create_set(%{name: "Shown", category: "luminous"})
      empty = create_empty_set(%{name: "Not filled yet", category: "luminous"})

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "luminous"})

      ids = Enum.map(sets, & &1["id"])
      assert to_string(shown.id) in ids
      refute to_string(empty.id) in ids

      body = graphql(conn, @detail_query, %{id: to_string(empty.id)})

      assert body["data"] == %{"meditationSet" => nil}
      refute Map.has_key?(body, "errors")
    end

    test "is never paginated", %{conn: conn} do
      for n <- 1..30, do: create_set(%{name: "Many #{n}", category: "sorrowful"})

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "sorrowful"})

      assert length(sets) >= 30
    end

    test "prints the byline REST prints: the set's own, else what its meditations agree on",
         %{conn: conn} do
      mystery = create_mystery()
      explicit = create_set(%{name: "Explicit", category: "glorious", author: "St. Alphonsus"})
      derived = create_empty_set(%{name: "Derived", category: "glorious"})

      for order <- 1..2 do
        m =
          create_meditation(mystery, %{author: "Bl. Anne Catherine Emmerich", source: "Visions"})

        {:ok, _} = Rosary.add_meditation_to_set(derived.id, m.id, order, actor: admin())
      end

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "glorious"})

      by_id = Map.new(sets, &{&1["id"], &1})
      rest = Map.new(rest_list(conn, "glorious"), &{to_string(&1["id"]), &1})

      assert by_id[to_string(explicit.id)]["author"] == "St. Alphonsus"
      assert by_id[to_string(derived.id)]["author"] == "Bl. Anne Catherine Emmerich"
      assert by_id[to_string(derived.id)]["source"] == "Visions"

      for {id, set} <- by_id do
        assert set["author"] == rest[id]["author"]
        assert set["source"] == rest[id]["source"]
      end
    end

    test "shows publishable artwork as one object, matching REST's image fields", %{conn: conn} do
      painted = create_set(%{name: "Painted", category: "joyful"})

      {:ok, _} =
        Rosary.update_meditation_set_artwork(
          painted,
          %{
            "image_key" => "sets/1/abc.jpg",
            "image_width" => 1600,
            "image_height" => 2400,
            "image_focal_y" => 0.2,
            "image_alt" => "The Annunciation.",
            "image_license" => "public_domain",
            "image_year" => "c. 1440"
          },
          actor: admin()
        )

      bare = create_set(%{name: "Bare", category: "joyful"})

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "joyful"})

      by_id = Map.new(sets, &{&1["id"], &1})
      rest = Map.new(rest_list(conn, "joyful"), &{to_string(&1["id"]), &1})

      artwork = by_id[to_string(painted.id)]["artwork"]
      expected = rest[to_string(painted.id)]

      assert artwork["url"] == expected["image_url"]
      assert artwork["alignment"] == expected["image_alignment"]
      assert artwork["focalX"] == expected["image_focal_x"]
      assert artwork["focalY"] == expected["image_focal_y"]
      assert artwork["width"] == expected["image_width"]
      assert artwork["height"] == expected["image_height"]
      assert artwork["alt"] == expected["image_alt"]
      assert artwork["attribution"]["year"] == "c. 1440"
      assert artwork["attribution"]["license"] == "public_domain"

      assert by_id[to_string(bare.id)]["artwork"] == nil
    end

    test "falls back to the author's portrait, as REST does", %{conn: conn} do
      {:ok, author} =
        Rosary.create_author(%{name: "Portrait #{System.unique_integer()}"}, actor: admin())

      {:ok, _} =
        Rosary.update_author_artwork(
          author,
          %{
            "image_key" => "authors/1/portrait.jpg",
            "image_width" => 800,
            "image_height" => 1000,
            "image_alt" => "A portrait.",
            "image_license" => "public_domain"
          },
          actor: admin()
        )

      linked = create_set(%{name: "Linked", category: "joyful", author_id: author.id})

      %{"data" => %{"visibleMeditationSets" => sets}} =
        graphql(conn, @list_query, %{category: "joyful"})

      artwork = Enum.find(sets, &(&1["id"] == to_string(linked.id)))["artwork"]
      assert artwork["alt"] == "A portrait."
      assert artwork["url"] =~ "authors/1/portrait.jpg"
    end

    test "signs nothing a query does not select", %{conn: conn} do
      create_set(%{name: "Unsigned", category: "joyful"})
      # Without credentials nothing can be signed; a shelf query must not try.
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      assert %{"data" => %{"visibleMeditationSets" => [_ | _]}} =
               graphql(conn, @list_query, %{category: "joyful"})
    end
  end

  describe "meditationSet" do
    setup do
      mystery = create_mystery()
      set = create_empty_set(%{name: "Prayed", category: "joyful"})

      first = create_meditation(mystery, %{content: "First", title: "One"})
      second = create_meditation(mystery, %{content: "Second"})
      third = create_meditation(mystery, %{content: "Third"})

      # Prayer order differs from id order, so only an explicit sort passes.
      {:ok, _} = Rosary.add_meditation_to_set(set.id, third.id, 1, actor: admin())
      {:ok, _} = Rosary.add_meditation_to_set(set.id, first.id, 2, actor: admin())
      {:ok, _} = Rosary.add_meditation_to_set(set.id, second.id, 3, actor: admin())

      {:ok, _} = Rosary.record_narration(first, "male", "voices/male/first.mp3", actor: admin())

      {:ok, _} =
        Rosary.record_narration(first, "female", "voices/female/first.mp3", actor: admin())

      %{set: set, mystery: mystery, first: first, second: second, third: third}
    end

    test "carries the meditations in prayer order, each with its mystery", %{
      conn: conn,
      set: set,
      mystery: mystery,
      first: first,
      second: second,
      third: third
    } do
      %{"data" => %{"meditationSet" => detail}} =
        graphql(conn, @detail_query, %{id: to_string(set.id)})

      memberships = detail["setMemberships"]
      assert Enum.map(memberships, & &1["order"]) == [1, 2, 3]

      assert Enum.map(memberships, & &1["meditation"]["id"]) ==
               Enum.map([third, first, second], &to_string(&1.id))

      for %{"meditation" => meditation} <- memberships do
        assert is_binary(meditation["content"])
        assert meditation["mystery"]["id"] == to_string(mystery.id)
      end

      rest =
        conn
        |> get("/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> get_in(["data", "meditations"])

      assert Enum.map(memberships, & &1["meditation"]["id"]) ==
               Enum.map(rest, &to_string(&1["id"]))
    end

    test "signs every narration, default voice first, each with its own expiry", %{
      conn: conn,
      set: set
    } do
      %{"data" => %{"meditationSet" => detail}} =
        graphql(conn, @detail_query, %{id: to_string(set.id)})

      [_third, %{"meditation" => first}, %{"meditation" => second}] = detail["setMemberships"]

      default = Voices.default().slug
      assert [%{"voice" => ^default} | _] = first["narrations"]
      assert length(first["narrations"]) == 2

      for narration <- first["narrations"] do
        assert narration["audio"]["url"] =~ "X-Amz-Signature="
        assert narration["audio"]["expiresAt"] =~ @expiry
      end

      assert first["narratedVoices"] == Enum.map(first["narrations"], & &1["voice"])

      # Nothing recorded: an empty list, never null.
      assert second["narrations"] == []
      assert second["narratedVoices"] == []
      assert second["narration"] == nil
    end

    test "recordings that cannot be signed are null, never a shorter list", %{
      conn: conn,
      set: set
    } do
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      %{"data" => %{"meditationSet" => detail}} =
        graphql(conn, @detail_query, %{id: to_string(set.id)})

      [_, %{"meditation" => first}, %{"meditation" => second}] = detail["setMemberships"]

      # The text still arrives; the audio is null, and narratedVoices says
      # it exists, so a client knows to try again rather than that there
      # is no recording.
      assert first["content"] == "First"
      assert first["narrations"] == nil
      assert first["narration"] == nil
      assert length(first["narratedVoices"]) == 2
      assert second["narrations"] == []
    end

    test "narration(preferring:) honours a recorded voice and falls back otherwise", %{
      conn: conn,
      set: set
    } do
      [non_default | _] = Enum.reject(Voices.list(), & &1.default)

      %{"data" => %{"meditationSet" => preferred}} =
        graphql(conn, @detail_query, %{id: to_string(set.id), voice: non_default.slug})

      [_, %{"meditation" => first}, _] = preferred["setMemberships"]
      assert first["narration"]["voice"] == non_default.slug

      %{"data" => %{"meditationSet" => unknown}} =
        graphql(conn, @detail_query, %{id: to_string(set.id), voice: "nobody"})

      [_, %{"meditation" => first}, _] = unknown["setMemberships"]
      assert first["narration"]["voice"] == Voices.default().slug
    end

    test "a hidden set is null, as REST answers 404", %{
      conn: conn,
      set: set,
      second: second
    } do
      {:ok, _} = Rosary.archive_meditation(second, actor: admin())

      body = graphql(conn, @detail_query, %{id: to_string(set.id)})

      assert body["data"] == %{"meditationSet" => nil}
      refute Map.has_key?(body, "errors")
      assert conn |> get("/api/meditation-sets/#{set.id}") |> json_response(404)
    end

    test "a missing set is null", %{conn: conn} do
      body = graphql(conn, @detail_query, %{id: "999999999"})

      assert body["data"] == %{"meditationSet" => nil}
    end

    test "every id is digits, so a client can read it as an integer", %{conn: conn, set: set} do
      body = graphql(conn, @detail_query, %{id: to_string(set.id)})

      ids =
        body
        |> collect_ids()
        |> Enum.reject(&is_nil/1)

      assert ids != []
      assert Enum.all?(ids, &(is_binary(&1) and &1 =~ ~r/^\d+$/)), inspect(ids)
    end
  end
end
