defmodule LumenViaeWeb.API.ContractTest do
  @moduledoc """
  The iOS API contract, enforced.

  Builds of the app in the wild decode these responses with non-optional
  Swift properties, so a key that stops arriving - or arrives with a
  different type - is a hard decoding failure for anyone who has not
  updated. There is no `/api/v1`: two URLs for one API would not help,
  because the old one could never be removed anyway. This file is the
  guarantee instead.

  The rule it encodes:

    * removing a shipped key, or changing its type, is BREAKING and fails
      here
    * adding a key is compatible and must not fail here or anywhere else

  Which is why the assertions below check presence and type rather than
  map equality. When a field is added to the API, it does not belong in
  these lists; the lists record what the shipped app already depends on.
  Only add to them once a field has shipped and clients rely on it.
  """
  use LumenViaeWeb.ConnCase, async: true

  alias LumenViae.Rosary

  # Every key the shipped iOS client decodes today. See the Codable structs
  # in ios/app/app/Models/: MeditationSet.swift, Meditation.swift,
  # Mystery.swift, APIResponse.swift.
  @summary_keys ~w(id name category description labels)
  @detail_keys ~w(id name category description labels meditations)
  @meditation_keys ~w(id title content author source audio_url mystery)
  @mystery_keys ~w(id name category order days_prayed description scripture_reference)
  @completion_keys ~w(id meditation_set_id completed_at)

  defp create_mystery(attrs \\ %{}) do
    defaults = %{
      name: "Contract Mystery #{System.unique_integer([:positive])}",
      category: "joyful",
      order: System.unique_integer([:positive]),
      days_prayed: "Monday, Thursday",
      description: "A description",
      scripture_reference: "Luke 1:26-38"
    }

    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs))
    mystery
  end

  defp create_populated_set do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Contract Set",
        category: "joyful",
        description: "A description",
        labels: ["Saints"]
      })

    mystery = create_mystery()

    {:ok, meditation} =
      Rosary.create_meditation(%{
        content: "Contract content",
        title: "A title",
        author: "An author",
        source: "A source",
        mystery_id: mystery.id
      })

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
    set
  end

  describe "every /api route" do
    # G1: production 301s lumenviae.fly.dev to www.lumenviae.org through
    # CanonicalHost in the :browser pipeline. URLSession follows a 301 on a
    # POST as a GET, so a completion would vanish with no error anywhere.
    # The test host is localhost, so nothing but this can see it.
    test "none passes through the :browser pipeline" do
      api_routes =
        Enum.filter(LumenViaeWeb.Router.__routes__(), &String.starts_with?(&1.path, "/api"))

      assert api_routes != []

      for route <- api_routes do
        # __routes__/0 leaves the pipelines out; route_info/4 has them.
        concrete = String.replace(route.path, ~r/:\w+/, "x")
        verb = route.verb |> to_string() |> String.upcase()

        assert %{route: route_path, pipe_through: pipes} =
                 Phoenix.Router.route_info(LumenViaeWeb.Router, verb, concrete, "localhost")

        assert route_path == route.path

        refute :browser in pipes,
               "#{verb} #{route.path} is behind :browser, which redirects the app's host"
      end
    end

    # G2: URLSession's default Accept, which the app leaves on every GET.
    test "the credential-free GET routes answer */* with 200 JSON", %{conn: conn} do
      set = create_populated_set()
      conn = Plug.Conn.put_req_header(conn, "accept", "*/*")

      for path <- [
            "/api/meditation-sets",
            "/api/meditation-sets?category=joyful",
            "/api/meditation-sets/#{set.id}",
            "/api/voices",
            "/api/mysteries",
            "/api/office/versions"
          ] do
        assert conn |> get(path) |> json_response(200), "#{path} did not answer */* with JSON"
      end
    end
  end

  describe "GET /api/meditation-sets" do
    test "every shipped summary key is present and correctly typed", %{conn: conn} do
      set = create_populated_set()

      [summary] =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      for key <- @summary_keys do
        assert Map.has_key?(summary, key),
               "the shipped app decodes #{key} on a set summary; removing it breaks installed builds"
      end

      assert summary["id"] == set.id
      assert is_integer(summary["id"])
      assert is_binary(summary["name"])
      assert is_binary(summary["category"])
      assert is_list(summary["labels"])
      assert Enum.all?(summary["labels"], &is_binary/1)
    end

    test "labels is an empty array rather than null when a set has none", %{conn: conn} do
      {:ok, _} = Rosary.create_meditation_set(%{name: "Bare", category: "joyful"})

      [summary] =
        conn
        |> get(~p"/api/meditation-sets?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      # `labels: [String]?` on iOS tolerates null, but a null would make the
      # picker fall back to a flat list rather than showing an empty group.
      assert summary["labels"] == []
    end

    test "the response is wrapped in a data key", %{conn: conn} do
      body = conn |> get(~p"/api/meditation-sets") |> json_response(200)

      assert Map.has_key?(body, "data")
      assert is_list(body["data"])
    end
  end

  describe "GET /api/meditation-sets/:id" do
    test "every shipped detail and meditation key is present and correctly typed", %{conn: conn} do
      set = create_populated_set()

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      for key <- @detail_keys do
        assert Map.has_key?(data, key),
               "the shipped app decodes #{key} on a set detail; removing it breaks installed builds"
      end

      assert is_list(data["meditations"])
      [meditation] = data["meditations"]

      for key <- @meditation_keys do
        assert Map.has_key?(meditation, key),
               "the shipped app decodes #{key} on a meditation; removing it breaks installed builds"
      end

      assert is_integer(meditation["id"])
      assert is_binary(meditation["content"])
      assert is_map(meditation["mystery"])

      for key <- @mystery_keys do
        assert Map.has_key?(meditation["mystery"], key),
               "the shipped app decodes #{key} on a nested mystery; removing it breaks installed builds"
      end
    end

    # D1: only the summary asserted these before.
    test "the set itself is correctly typed", %{conn: conn} do
      set = create_populated_set()

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert is_integer(data["id"])
      assert data["id"] == set.id
      assert is_binary(data["name"])
      assert is_binary(data["category"])
    end

    # D2: one bad element fails the whole set for the app, so every
    # meditation is checked, including ones with every optional field null.
    test "every meditation and its mystery are correctly typed", %{conn: conn} do
      set = create_populated_set()

      bare_mystery =
        create_mystery(%{days_prayed: nil, description: nil, scripture_reference: nil})

      {:ok, bare} = Rosary.create_meditation(%{content: "Bare", mystery_id: bare_mystery.id})
      {:ok, _} = Rosary.add_meditation_to_set(set.id, bare.id, 2)

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert length(data["meditations"]) == 2

      for meditation <- data["meditations"] do
        assert is_integer(meditation["id"])
        assert is_binary(meditation["content"])

        for key <- ~w(title author source audio_url) do
          assert_string_or_nil(meditation[key], key)
        end

        assert is_list(meditation["narrations"])

        for narration <- meditation["narrations"] do
          assert is_binary(narration["voice"])
          assert is_binary(narration["audio_url"])
        end

        mystery = meditation["mystery"]
        assert is_map(mystery), "mystery must be a map, never null or an unloaded relation"
        assert is_integer(mystery["id"])
        assert is_binary(mystery["name"])
        assert is_binary(mystery["category"])
        assert is_integer(mystery["order"])

        for key <- ~w(description scripture_reference days_prayed) do
          assert_string_or_nil(mystery[key], "mystery.#{key}")
        end
      end
    end

    # D3: the player reads meditations[i] as decade i. Added in an order
    # that is neither id order nor heap order.
    test "meditations come back in prayer order, not id order", %{conn: conn} do
      {:ok, set} = Rosary.create_meditation_set(%{name: "Ordered", category: "joyful"})
      mystery = create_mystery()

      [m1, m2, m3] =
        for n <- 1..3 do
          {:ok, m} = Rosary.create_meditation(%{content: "M#{n}", mystery_id: mystery.id})
          m
        end

      {:ok, _} = Rosary.add_meditation_to_set(set.id, m3.id, 1)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, m1.id, 2)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, m2.id, 3)

      data =
        conn
        |> get(~p"/api/meditation-sets/#{set.id}")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.map(data["meditations"], & &1["id"]) == [m3.id, m1.id, m2.id]
    end

    # D6: the app's URLCache honours this, and a cached response would
    # replay presigned URLs after they expire.
    test "the detail is never cached", %{conn: conn} do
      set = create_populated_set()
      conn = get(conn, ~p"/api/meditation-sets/#{set.id}")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    end
  end

  describe "GET /api/mysteries" do
    test "every shipped mystery key is present and correctly typed", %{conn: conn} do
      mystery = create_mystery()

      data =
        conn
        |> get(~p"/api/mysteries?category=joyful")
        |> json_response(200)
        |> Map.fetch!("data")

      found = Enum.find(data, &(&1["id"] == mystery.id))
      assert found, "the created mystery was not returned"

      for key <- @mystery_keys do
        assert Map.has_key?(found, key),
               "the shipped app decodes #{key} on a mystery; removing it breaks installed builds"
      end

      assert is_integer(found["id"])
      assert is_binary(found["name"])
      assert is_binary(found["category"])
      assert is_integer(found["order"])
    end
  end

  describe "POST /api/completions" do
    test "every shipped completion key is present and correctly typed", %{conn: conn} do
      {:ok, set} = Rosary.create_meditation_set(%{name: "Completion Set", category: "joyful"})

      data =
        conn
        |> post(~p"/api/completions", %{meditation_set_id: set.id})
        |> json_response(201)
        |> Map.fetch!("data")

      for key <- @completion_keys do
        assert Map.has_key?(data, key),
               "the shipped app decodes #{key} on a completion; removing it breaks installed builds"
      end

      assert is_integer(data["id"])
      # C2: equality alone would stay green if ids became UUIDs.
      assert is_integer(data["meditation_set_id"])
      assert data["meditation_set_id"] == set.id
      # iOS decodes completed_at as a String, not a Date - it must stay a
      # string in the JSON even though the column is a timestamp.
      assert is_binary(data["completed_at"])
    end
  end
end
