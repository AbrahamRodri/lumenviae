defmodule LumenViaeWeb.JsonApi.LibraryTest do
  @moduledoc """
  `GET /api/v2/prayer-book` and `GET /api/v2/chant-library`: the Prayer
  Book and the Chant Library, each one document. The bare request is the
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
    {"/chant-library", "chant_library", :chant_library, ~w(groups chants)}
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
end
