defmodule LumenViaeWeb.JsonApi.MeditationSetsTest do
  @moduledoc """
  `GET /api/v2/meditation-sets` and `GET /api/v2/meditation-sets/:id`,
  held to what the unversioned REST endpoints and GraphQL serve: the same
  sets, the same order, the same bylines and artwork, meditations in prayer
  order, and a hidden set absent from the list and not found by id.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Voices

  @expiry ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  @in_prayer_order "include=set_memberships.meditation.mystery"

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

  defp create_empty_set(attrs) do
    defaults = %{name: "V2 Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "V2 Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: 100 + rem(System.unique_integer([:positive]), 100_000),
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

  defp list(conn, query) do
    conn |> get_v2("/meditation-sets?" <> query) |> v2_response(200) |> Map.fetch!("data")
  end

  defp rest_list(conn, category) do
    conn
    |> get("/api/meditation-sets?category=#{category}")
    |> json_response(200)
    |> Map.fetch!("data")
  end

  # The included resources of one type, by id.
  defp included(body, type) do
    body
    |> Map.get("included", [])
    |> Enum.filter(&(&1["type"] == type))
    |> Map.new(&{&1["id"], &1})
  end

  describe "the list" do
    test "lists the same sets as REST, in the same order", %{conn: conn} do
      a = create_set(%{name: "A", category: "seven_sorrows"})
      _b = create_set(%{name: "B", category: "seven_sorrows"})
      c = create_set(%{name: "C", category: "seven_sorrows"})
      # Updated after the others, so heap order would put it last.
      {:ok, _} = Rosary.update_meditation_set(a, %{description: "Edited"}, actor: admin())
      _other = create_set(%{name: "Elsewhere", category: "glorious"})

      sets = list(conn, "category=seven_sorrows")
      rest = rest_list(conn, "seven_sorrows")

      assert Enum.map(sets, & &1["id"]) == Enum.map(rest, &to_string(&1["id"]))
      assert Enum.all?(sets, &(&1["type"] == "meditation_set"))
      assert Enum.all?(sets, &(&1["attributes"]["category"] == "seven_sorrows"))
      assert List.first(sets)["id"] == to_string(a.id)
      assert List.last(sets)["id"] == to_string(c.id)
    end

    test "leaves out a set hidden by an archived meditation, or holding none", %{conn: conn} do
      mystery = create_mystery()
      shown = create_set(%{name: "Shown", category: "luminous"})
      hidden = create_empty_set(%{name: "Hidden", category: "luminous"})
      empty = create_empty_set(%{name: "Not filled yet", category: "luminous"})
      archived = create_meditation(mystery, %{content: "Withdrawn"})
      {:ok, _} = Rosary.add_meditation_to_set(hidden.id, archived.id, 1, actor: admin())
      {:ok, _} = Rosary.archive_meditation(archived, actor: admin())

      ids = conn |> list("category=luminous") |> Enum.map(& &1["id"])

      assert to_string(shown.id) in ids
      refute to_string(hidden.id) in ids
      refute to_string(empty.id) in ids
    end

    test "is never paginated", %{conn: conn} do
      for n <- 1..30, do: create_set(%{name: "Many #{n}", category: "sorrowful"})

      body = conn |> get_v2("/meditation-sets?category=sorrowful") |> v2_response(200)

      assert length(body["data"]) >= 30
      refute Map.has_key?(body["links"], "next")
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

      by_id = conn |> list("category=glorious") |> Map.new(&{&1["id"], &1["attributes"]})
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

      by_id = conn |> list("category=joyful") |> Map.new(&{&1["id"], &1["attributes"]})
      expected = conn |> rest_list("joyful") |> Enum.find(&(&1["id"] == painted.id))
      artwork = by_id[to_string(painted.id)]["artwork"]

      assert artwork["url"] == expected["image_url"]
      assert artwork["alignment"] == expected["image_alignment"]
      assert artwork["focal_x"] == expected["image_focal_x"]
      assert artwork["focal_y"] == expected["image_focal_y"]
      assert artwork["width"] == expected["image_width"]
      assert artwork["height"] == expected["image_height"]
      assert artwork["alt"] == expected["image_alt"]
      assert artwork["attribution"]["year"] == "c. 1440"
      assert artwork["attribution"]["license"] == "public_domain"

      assert by_id[to_string(bare.id)]["artwork"] == nil
    end

    test "signs nothing a request does not ask for", %{conn: conn} do
      create_set(%{name: "Unsigned", category: "joyful"})
      # Without credentials nothing can be signed; a shelf must not try.
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      body =
        conn
        |> get_v2("/meditation-sets?category=joyful&" <> @in_prayer_order)
        |> v2_response(200)

      assert [_ | _] = body["data"]

      for {_id, meditation} <- included(body, "meditation") do
        refute Map.has_key?(meditation["attributes"], "narrations")
        assert is_list(meditation["attributes"]["narrated_voices"])
      end
    end
  end

  describe "one set" do
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

    defp detail(conn, set, query \\ @in_prayer_order) do
      conn |> get_v2("/meditation-sets/#{set.id}?" <> query) |> v2_response(200)
    end

    # The set's meditations in prayer order: its memberships in the order
    # the response lists them, each followed to the included meditation.
    defp in_prayer_order(body) do
      memberships = included(body, "set_membership")
      meditations = included(body, "meditation")

      body["data"]["relationships"]["set_memberships"]["data"]
      |> Enum.map(fn %{"id" => id} -> memberships[id] end)
      |> Enum.map(fn membership ->
        {membership["attributes"]["order"],
         meditations[membership["relationships"]["meditation"]["data"]["id"]]}
      end)
    end

    test "carries the meditations in prayer order, each with its mystery", %{
      conn: conn,
      set: set,
      mystery: mystery,
      first: first,
      second: second,
      third: third
    } do
      body = detail(conn, set)
      ordered = in_prayer_order(body)

      assert Enum.map(ordered, &elem(&1, 0)) == [1, 2, 3]

      assert Enum.map(ordered, &elem(&1, 1)["id"]) ==
               Enum.map([third, first, second], &to_string(&1.id))

      for {_order, meditation} <- ordered do
        assert is_binary(meditation["attributes"]["content"])
        assert meditation["relationships"]["mystery"]["data"]["id"] == to_string(mystery.id)
      end

      assert %{"attributes" => %{"scripture_reference" => "Luke 1:26-38"}} =
               included(body, "mystery")[to_string(mystery.id)]

      rest =
        conn
        |> get("/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> get_in(["data", "meditations"])

      assert Enum.map(ordered, &elem(&1, 1)["id"]) == Enum.map(rest, &to_string(&1["id"]))
    end

    test "signs every narration it is asked for, default voice first, each with its own expiry",
         %{conn: conn, set: set} do
      body =
        detail(
          conn,
          set,
          @in_prayer_order <> "&fields[meditation]=content,narrated_voices,narrations"
        )

      [_third, {2, first}, {3, second}] = in_prayer_order(body)

      default = Voices.default().slug
      assert [%{"voice" => ^default} | _] = first["attributes"]["narrations"]
      assert length(first["attributes"]["narrations"]) == 2

      for narration <- first["attributes"]["narrations"] do
        assert narration["audio"]["url"] =~ "X-Amz-Signature="
        assert narration["audio"]["expires_at"] =~ @expiry
      end

      assert first["attributes"]["narrated_voices"] ==
               Enum.map(first["attributes"]["narrations"], & &1["voice"])

      # Nothing recorded: an empty list, never null.
      assert second["attributes"]["narrations"] == []
      assert second["attributes"]["narrated_voices"] == []
    end

    # Exactly what a client generated from priv/openapi/v2.json sends: the
    # deepObject parameter percent-encoded, the list comma-separated.
    test "reads fields and includes as a generated client encodes them", %{conn: conn, set: set} do
      body =
        detail(
          conn,
          set,
          "include=set_memberships.meditation.mystery" <>
            "&fields%5Bmeditation%5D=title%2Ccontent%2Cnarrations"
        )

      [_, {2, first}, _] = in_prayer_order(body)

      assert Map.keys(first["attributes"]) |> Enum.sort() == ["content", "narrations", "title"]
      assert length(first["attributes"]["narrations"]) == 2
    end

    test "recordings that cannot be signed are null, never a shorter list", %{
      conn: conn,
      set: set
    } do
      put_env([{:ex_aws, :access_key_id, nil}, {:ex_aws, :secret_access_key, nil}])

      body =
        detail(
          conn,
          set,
          @in_prayer_order <> "&fields[meditation]=content,narrated_voices,narrations"
        )

      [_, {2, first}, {3, second}] = in_prayer_order(body)

      assert first["attributes"]["content"] == "First"
      assert first["attributes"]["narrations"] == nil
      assert length(first["attributes"]["narrated_voices"]) == 2
      assert second["attributes"]["narrations"] == []
    end

    test "is not found when the set is hidden or does not exist", %{
      conn: conn,
      set: set,
      third: third
    } do
      empty = create_empty_set(%{name: "Not filled yet"})
      {:ok, _} = Rosary.archive_meditation(third, actor: admin())

      for id <- [set.id, empty.id, 999_999_999] do
        body = conn |> get_v2("/meditation-sets/#{id}") |> v2_response(404)
        assert [%{"code" => "not_found", "status" => "404"}] = body["errors"]
      end
    end
  end
end
