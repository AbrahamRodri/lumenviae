defmodule LumenViaeWeb.Graphql.LibraryTest do
  @moduledoc """
  GraphQL's `prayerBook` and `chantLibrary`: the same documents as
  `GET /api/v2/prayer-book` and `GET /api/v2/chant-library`, their
  sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Library

  test "the version and the date alone", %{conn: conn} do
    assert %{"data" => data} =
             graphql(conn, """
             { prayerBook { id version updatedAt } chantLibrary { id version updatedAt } }
             """)

    for {field, document} <- [{"prayerBook", :prayer_book}, {"chantLibrary", :chant_library}] do
      %{version: version, updated_at: updated_at} = Library.stamp(document)

      assert data[field] == %{
               "id" => "current",
               "version" => version,
               "updatedAt" => DateTime.to_iso8601(updated_at)
             }
    end
  end

  test "the Prayer Book's chapters, with their sections", %{conn: conn} do
    body =
      graphql(conn, """
      { prayerBook { chapters { id prayerIds sections { title prayerIds } } prayers { id latin } } }
      """)

    refute body["errors"]

    %{"chapters" => chapters, "prayers" => prayers} = get_in(body, ["data", "prayerBook"])

    assert Enum.map(chapters, & &1["id"]) ==
             Enum.map(Library.sections(:prayer_book)["chapters"], & &1["id"])

    assert length(prayers) == length(Library.sections(:prayer_book)["prayers"])
    assert Enum.all?(chapters, &(&1["sections"] != []))
  end

  test "every chant with its recording, score and lines", %{conn: conn} do
    body =
      graphql(conn, """
      { chantLibrary {
          groups { id parts { title chantIds } }
          chants { id groupId duration audio { url bytes sha256 }
                   score { file aspectRatio url } lines { latin start end part } } } }
      """)

    refute body["errors"]

    chants = get_in(body, ["data", "chantLibrary", "chants"])
    file = Library.sections(:chant_library)["chants"]

    assert Enum.map(chants, & &1["id"]) == Enum.map(file, & &1["id"])
    assert Enum.map(chants, & &1["audio"]) == Enum.map(file, & &1["audio"])
  end
end
