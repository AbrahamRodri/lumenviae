defmodule LumenViaeWeb.Graphql.LibraryTest do
  @moduledoc """
  GraphQL's `prayerBook`, `chantLibrary` and `consecration`: the same
  documents as `GET /api/v2/prayer-book`, `GET /api/v2/chant-library` and
  `GET /api/v2/consecration`, their sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Library

  test "the version and the date alone", %{conn: conn} do
    assert %{"data" => data} =
             graphql(conn, """
             { prayerBook { id version updatedAt } chantLibrary { id version updatedAt }
               consecration { id version updatedAt } }
             """)

    for {field, document} <- [
          {"prayerBook", :prayer_book},
          {"chantLibrary", :chant_library},
          {"consecration", :consecration}
        ] do
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

  test "the Consecration's days with their readings, its phases, prayers and feasts", %{
    conn: conn
  } do
    body =
      graphql(conn, """
      { consecration {
          phases { id name subtitle firstDay lastDay painting prayerIds }
          days { number phaseId title journalPrompt readings { order title text source } }
          prayers { id title latinTitle english latin }
          feasts { id name month day description } } }
      """)

    refute body["errors"]

    %{"days" => days, "phases" => phases, "prayers" => prayers, "feasts" => feasts} =
      get_in(body, ["data", "consecration"])

    file = Library.sections(:consecration)

    assert Enum.map(days, & &1["number"]) == Enum.map(file["days"], & &1["number"])

    assert Enum.map(days, &Enum.map(&1["readings"], fn reading -> reading["text"] end)) ==
             Enum.map(file["days"], &Enum.map(&1["readings"], fn reading -> reading["text"] end))

    assert Enum.map(phases, & &1["prayerIds"]) == Enum.map(file["phases"], & &1["prayer_ids"])
    assert Enum.map(prayers, & &1["latin"]) == Enum.map(file["prayers"], & &1["latin"])
    assert length(feasts) == length(file["feasts"])
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
