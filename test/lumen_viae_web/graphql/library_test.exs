defmodule LumenViaeWeb.Graphql.LibraryTest do
  @moduledoc """
  GraphQL's `prayerBook`, `chantLibrary`, `consecration` and
  `trueDevotion`: the same documents as `GET /api/v2/prayer-book`,
  `GET /api/v2/chant-library`, `GET /api/v2/consecration` and
  `GET /api/v2/true-devotion`, their sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Library

  test "the version and the date alone", %{conn: conn} do
    assert %{"data" => data} =
             graphql(conn, """
             { prayerBook { id version updatedAt } chantLibrary { id version updatedAt }
               consecration { id version updatedAt } trueDevotion { id version updatedAt }
               carloAcutis { id version updatedAt }
               marianLibrary { id version updatedAt } }
             """)

    for {field, document} <- [
          {"prayerBook", :prayer_book},
          {"chantLibrary", :chant_library},
          {"consecration", :consecration},
          {"trueDevotion", :true_devotion},
          {"carloAcutis", :carlo_acutis},
          {"marianLibrary", :marian_library}
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

  test "True Devotion's chapters with their paragraphs, its parts and about", %{conn: conn} do
    body =
      graphql(conn, """
      { trueDevotion {
          about { title author translator sourceNote }
          parts { number title }
          chapters { id part title paragraphs { id kind text } } } }
      """)

    refute body["errors"]

    %{"about" => about, "parts" => parts, "chapters" => chapters} =
      get_in(body, ["data", "trueDevotion"])

    file = Library.sections(:true_devotion)

    assert about["sourceNote"] == file["about"]["source_note"]
    assert Enum.map(parts, & &1["title"]) == Enum.map(file["parts"], & &1["title"])
    assert Enum.map(chapters, & &1["id"]) == Enum.map(file["chapters"], & &1["id"])

    assert Enum.map(chapters, &Enum.map(&1["paragraphs"], fn paragraph -> paragraph["text"] end)) ==
             Enum.map(
               file["chapters"],
               &Enum.map(&1["paragraphs"], fn paragraph -> paragraph["text"] end)
             )
  end

  test "St. Carlo's shelves with their readings and doors, his timeline, rule and prayer", %{
    conn: conn
  } do
    body =
      graphql(conn, """
      { carloAcutis {
          feast { month day name inMissal }
          shelves { id marginLabel readings { id paragraphs quote { text citation }
                    feast { name } doors { kind target note } } }
          timeline { year readingId }
          rule { name act actTitle }
          sayings prayer } }
      """)

    refute body["errors"]

    page = get_in(body, ["data", "carloAcutis"])
    file = Library.sections(:carlo_acutis)

    assert page["feast"]["inMissal"] == false
    assert Enum.map(page["shelves"], & &1["id"]) == Enum.map(file["shelves"], & &1["id"])
    assert page["sayings"] == file["sayings"]
    assert page["prayer"] == file["prayer"]
    assert Enum.map(page["rule"], & &1["act"]) == Enum.map(file["rule"], & &1["act"])
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
