defmodule LumenViaeWeb.JsonApi.LibraryTest do
  @moduledoc """
  `GET /api/v2/prayer-book`, `GET /api/v2/chant-library`,
  `GET /api/v2/consecration` and `GET /api/v2/true-devotion`: the Prayer
  Book, the Chant Library, the 33-day Consecration and the book True
  Devotion, each one document. The bare request is the
  version and the date, which is how a device asks whether its saved copy
  is current; the sections come when named in `fields[<type>]=`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.Library

  # The strict form the app's ISO8601DateFormatter accepts: whole seconds, Z.
  @instant ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

  @documents [
    {"/prayer-book", "prayer_book", :prayer_book, ~w(prayers chapters)},
    {"/chant-library", "chant_library", :chant_library, ~w(groups chants)},
    {"/consecration", "consecration", :consecration, ~w(phases days prayers feasts)},
    {"/true-devotion", "true_devotion", :true_devotion, ~w(about parts chapters)},
    {"/carlo-acutis", "carlo_acutis", :carlo_acutis,
     ~w(feast shelves timeline rule sayings prayer)}
  ]

  for {path, type, document, sections} <- @documents do
    describe "GET #{path}" do
      test "the bare request carries the version and the date, and nothing else", %{conn: conn} do
        conn = get_v2(conn, unquote(path))
        body = v2_response(conn, 200)

        assert %{"type" => unquote(type), "id" => "current", "attributes" => attributes} =
                 body["data"]

        assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]

        %{version: version, updated_at: updated_at} = Library.stamp(unquote(document))
        assert attributes["version"] == version
        assert attributes["version"] =~ ~r/\A[0-9a-f]{16,}\z/
        assert attributes["updated_at"] =~ @instant
        assert attributes["updated_at"] == DateTime.to_iso8601(updated_at)

        assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      end

      test "the version is the same on every request", %{conn: conn} do
        versions =
          for _ <- 1..3 do
            conn
            |> get_v2(unquote(path))
            |> v2_response(200)
            |> get_in(["data", "attributes", "version"])
          end

        assert [version, version, version] = versions
      end

      test "the sections come when asked for, exactly as the file holds them", %{conn: conn} do
        fields = Enum.join(["version", "updated_at" | unquote(sections)], ",")

        attributes =
          conn
          |> get_v2("#{unquote(path)}?fields[#{unquote(type)}]=#{fields}")
          |> v2_response(200)
          |> get_in(["data", "attributes"])

        assert Map.keys(attributes) |> Enum.sort() ==
                 Enum.sort(["updated_at", "version" | unquote(sections)])

        for section <- unquote(sections) do
          assert attributes[section] == Library.sections(unquote(document))[section], section
        end
      end
    end
  end

  describe "the Prayer Book" do
    setup %{conn: conn} do
      attributes =
        conn
        |> get_v2("/prayer-book?fields[prayer_book]=prayers,chapters")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      %{prayers: attributes["prayers"], chapters: attributes["chapters"]}
    end

    test "every prayer carries every field of the contract", %{prayers: prayers} do
      for prayer <- prayers do
        assert Map.keys(prayer) |> Enum.sort() ==
                 ~w(english english_name id latin latin_title list_title note origin search_words title)
      end
    end

    test "every chapter carries its sections, and its prayers are their union", %{
      prayers: prayers,
      chapters: chapters
    } do
      ids = MapSet.new(prayers, & &1["id"])

      for chapter <- chapters do
        assert Map.keys(chapter) |> Enum.sort() ==
                 ~w(id latin_title note numeral prayer_ids search_words sections title topic)

        assert chapter["sections"] != []
        assert Enum.all?(chapter["prayer_ids"], &MapSet.member?(ids, &1))

        assert chapter["prayer_ids"] ==
                 chapter["sections"] |> Enum.flat_map(& &1["prayer_ids"]) |> Enum.uniq()
      end
    end

    test "a prayer with Latin pairs it with the English line for line", %{prayers: prayers} do
      for %{"latin" => latin, "english" => english} <- prayers, latin do
        assert length(String.split(latin, "\n")) == length(String.split(english, "\n"))
      end
    end
  end

  describe "the Consecration" do
    setup %{conn: conn} do
      conn
      |> get_v2("/consecration?fields[consecration]=phases,days,prayers,feasts")
      |> v2_response(200)
      |> get_in(["data", "attributes"])
      |> then(
        &%{phases: &1["phases"], days: &1["days"], prayers: &1["prayers"], feasts: &1["feasts"]}
      )
    end

    test "every item carries every field of the contract", %{
      phases: phases,
      days: days,
      prayers: prayers,
      feasts: feasts
    } do
      for phase <- phases do
        assert Map.keys(phase) |> Enum.sort() ==
                 ~w(first_day id last_day name painting prayer_ids subtitle)
      end

      for day <- days do
        assert Map.keys(day) |> Enum.sort() == ~w(journal_prompt number phase_id readings title)

        for reading <- day["readings"] do
          assert Map.keys(reading) |> Enum.sort() == ~w(order source text title)
        end
      end

      for prayer <- prayers do
        assert Map.keys(prayer) |> Enum.sort() == ~w(english id latin latin_title title)
      end

      for feast <- feasts do
        assert Map.keys(feast) |> Enum.sort() == ~w(day description id month name)
      end
    end

    test "the 33 days and Consecration Day, in five phases", %{phases: phases, days: days} do
      assert Enum.map(phases, & &1["id"]) ==
               ~w(preparatory knowledge_of_self knowledge_of_mary knowledge_of_jesus consecration_day)

      assert Enum.map(phases, &{&1["first_day"], &1["last_day"]}) ==
               [{1, 12}, {13, 19}, {20, 26}, {27, 33}, {34, 34}]

      assert Enum.map(days, & &1["number"]) == Enum.to_list(1..34)

      for day <- days do
        phase = Enum.find(phases, &(&1["id"] == day["phase_id"]))
        assert day["number"] in phase["first_day"]..phase["last_day"]
        assert day["readings"] != []
      end
    end

    test "every prayer a phase names is served, in English and where it has one, Latin", %{
      phases: phases,
      prayers: prayers
    } do
      by_id = Map.new(prayers, &{&1["id"], &1})

      for phase <- phases, id <- phase["prayer_ids"] do
        assert %{"english" => english} = Map.fetch!(by_id, id)
        assert english != ""
      end

      assert by_id["act_of_consecration"]["latin"] == nil
      assert by_id["veni_creator"]["latin_title"] == "Veni Creator Spiritus"

      for %{"latin" => latin, "english" => english} <- prayers, latin do
        assert length(String.split(latin, "\n")) == length(String.split(english, "\n"))
      end
    end

    test "the feasts it may end on are real dates", %{feasts: feasts} do
      assert length(feasts) == 9

      for %{"month" => month, "day" => day} <- feasts do
        assert {:ok, _date} = Date.new(2024, month, day)
      end
    end
  end

  describe "the Chant Library" do
    setup %{conn: conn} do
      attributes =
        conn
        |> get_v2("/chant-library?fields[chant_library]=groups,chants")
        |> v2_response(200)
        |> get_in(["data", "attributes"])

      %{groups: attributes["groups"], chants: attributes["chants"]}
    end

    test "every chant carries every field of the contract", %{chants: chants} do
      assert length(chants) == 104

      for chant <- chants do
        assert Map.keys(chant) |> Enum.sort() ==
                 ~w(audio detail duration english_title group_id id latin_title lines prayer_ids score setting source_url)

        for line <- chant["lines"] do
          assert Map.keys(line) |> Enum.sort() == ~w(end english latin part start)
        end
      end
    end

    test "every recording and score page has a public URL named by its checksum", %{
      chants: chants
    } do
      for chant <- chants do
        %{"url" => url, "bytes" => bytes, "sha256" => sha256} = chant["audio"]

        assert url =~ ~r{\Ahttps://}

        assert String.ends_with?(
                 url,
                 "/chants/audio/#{chant["id"]}-#{binary_part(sha256, 0, 12)}.m4a"
               )

        assert is_integer(bytes) and bytes > 0
        assert sha256 =~ ~r/\A[0-9a-f]{64}\z/

        for page <- chant["score"] do
          assert Map.keys(page) |> Enum.sort() == ~w(aspect_ratio bytes caption file sha256 url)

          assert String.ends_with?(
                   page["url"],
                   "/chants/scores/#{page["file"]}-#{binary_part(page["sha256"], 0, 12)}.lvscore"
                 )

          assert is_integer(page["bytes"]) and page["bytes"] > 0
        end
      end
    end

    test "every chant stands in its group's parts, and every part's chant exists", %{
      groups: groups,
      chants: chants
    } do
      ids = Enum.map(chants, & &1["id"])

      parts =
        Map.new(groups, &{&1["id"], Enum.flat_map(&1["parts"], fn part -> part["chant_ids"] end)})

      assert Enum.sort(Enum.flat_map(Map.values(parts), & &1)) |> Enum.uniq() == Enum.sort(ids)

      for chant <- chants do
        assert chant["id"] in Map.fetch!(parts, chant["group_id"])
      end
    end
  end

  describe "True Devotion" do
    setup %{conn: conn} do
      conn
      |> get_v2("/true-devotion?fields[true_devotion]=about,parts,chapters")
      |> v2_response(200)
      |> get_in(["data", "attributes"])
      |> then(&%{about: &1["about"], parts: &1["parts"], chapters: &1["chapters"]})
    end

    test "every item carries every field of the contract", %{
      about: about,
      parts: parts,
      chapters: chapters
    } do
      assert Map.keys(about) |> Enum.sort() == ~w(author source_note title translator)

      for part <- parts, do: assert(Map.keys(part) |> Enum.sort() == ~w(number title))

      for chapter <- chapters do
        assert Map.keys(chapter) |> Enum.sort() == ~w(id paragraphs part title)

        for paragraph <- chapter["paragraphs"] do
          assert Map.keys(paragraph) |> Enum.sort() == ~w(id kind text)
        end
      end
    end

    test "the whole book: an Introduction and two parts, the Act of Consecration last", %{
      about: about,
      parts: parts,
      chapters: chapters
    } do
      assert about["title"] == "True Devotion to the Blessed Virgin"
      assert about["source_note"] =~ "public domain"
      assert Enum.map(parts, & &1["number"]) == [1, 2]
      assert %{"id" => "introduction", "part" => 0} = hd(chapters)
      assert %{"id" => "formula", "part" => 2} = List.last(chapters)
    end
  end

  describe "St. Carlo Acutis" do
    setup %{conn: conn} do
      conn
      |> get_v2("/carlo-acutis?fields[carlo_acutis]=feast,shelves,timeline,rule,sayings,prayer")
      |> v2_response(200)
      |> get_in(["data", "attributes"])
      |> then(&%{page: &1})
    end

    test "every item carries every field of the contract", %{page: page} do
      assert Map.keys(page["feast"]) |> Enum.sort() ==
               ~w(day in_missal kept_by month name painting reading_id reading_name)

      for shelf <- page["shelves"] do
        assert Map.keys(shelf) |> Enum.sort() ==
                 ~w(footnote icon id margin_label readings subtitle title)

        for reading <- shelf["readings"] do
          assert Map.keys(reading) |> Enum.sort() ==
                   ~w(detail doors feast id painting paragraphs parts quote tables title)

          for door <- reading["doors"] do
            assert Map.keys(door) |> Enum.sort() == ~w(icon kind note target title)
          end
        end
      end

      for moment <- page["timeline"],
          do: assert(Map.keys(moment) |> Enum.sort() == ~w(line reading_id title year))

      for habit <- page["rule"] do
        assert Map.keys(habit) |> Enum.sort() == ~w(act act_title icon name often reading_id)
      end
    end

    test "his life and his devotions, and a prayer for his intercession", %{page: page} do
      assert Enum.map(page["shelves"], & &1["id"]) == ~w(carlo_life carlo_devotions)
      assert %{"month" => 10, "day" => 12, "in_missal" => false} = page["feast"]
      assert "Not I, but God." in page["sayings"]
      assert page["prayer"] =~ "live as originals and not as copies"
    end
  end
end
