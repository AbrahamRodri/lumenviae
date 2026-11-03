defmodule LumenViaeWeb.JsonApi.PrayerBookSpanishTest do
  @moduledoc """
  `GET /api/v2/prayer-book?lang=es`: the Prayer Book with its Spanish in
  `translations`. Without `lang` (or with `en`, or a language not served)
  the document is exactly what it was before Spanish, `translations` empty.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook.Current
  alias LumenViae.Rosary.PrayerBook.Spanish

  @sections "version,updated_at,prayers,chapters,orders,marian_antiphons"

  defp attributes(query) do
    build_conn()
    |> get_v2("/prayer-book?fields[prayer_book]=" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes"])
  end

  test "missing, en or a language not served: the English document, unchanged" do
    english = attributes(@sections)

    for lang <- ["en", "EN", "fr", "", "spanish"] do
      assert attributes(@sections <> "&lang=" <> lang) == english, lang
    end

    stamp = Library.stamp(:prayer_book)
    assert english["version"] == stamp.version
    assert english["updated_at"] == DateTime.to_iso8601(stamp.updated_at)

    for lang <- ["", "&lang=en", "&lang=fr"] do
      assert attributes("translations" <> lang) == %{"translations" => []}, lang
    end
  end

  test "es: the Spanish in translations, every other section the English" do
    english = attributes(@sections)
    spanish = attributes(@sections <> ",translations&lang=es")

    assert spanish["translations"] == Jason.decode!(Jason.encode!(Spanish.prayers()))
    assert length(spanish["translations"]) == length(Spanish.prayers())

    assert %{"id" => "act_of_faith", "title" => "Acto de Fe", "text" => "Señor Dios," <> _} =
             Enum.find(spanish["translations"], &(&1["id"] == "act_of_faith"))

    assert %{"id" => "hail_mary", "title" => "Ave María"} =
             Enum.find(spanish["translations"], &(&1["id"] == "hail_mary"))

    for prayer <- spanish["translations"] do
      assert Map.get(prayer, "ai_translated", true) == true
    end

    assert Map.drop(spanish, ~w(translations version updated_at)) ==
             Map.drop(english, ~w(version updated_at))
  end

  test "es has a version and a date of its own, and a region reads as es" do
    spanish = attributes("version,updated_at&lang=es")
    english = attributes("version,updated_at")

    refute spanish["version"] == english["version"]
    assert spanish["version"] == Current.stamp("es").version
    assert spanish["updated_at"] == DateTime.to_iso8601(Current.stamp("es").updated_at)
    refute DateTime.compare(Current.stamp("es").updated_at, Spanish.updated_at()) == :lt

    assert attributes("version,updated_at,translations&lang=es-MX") ==
             attributes("version,updated_at,translations&lang=es")
  end

  test "the bare request with es is the Spanish version and date alone" do
    attributes =
      build_conn()
      |> get_v2("/prayer-book?lang=es")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
    assert attributes["version"] == Current.stamp("es").version
  end
end
