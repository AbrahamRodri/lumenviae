defmodule LumenViaeWeb.JsonApi.ChantLibrarySpanishTest do
  @moduledoc """
  `GET /api/v2/chant-library?lang=es`: the Chant Library with its chants'
  and groups' names in Spanish in `translations`. Without `lang` (or with
  `en`, or a language not served) the document is exactly what it was
  before Spanish, `translations` empty.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.ChantLibrary.Current
  alias LumenViae.Rosary.ChantLibrary.Spanish
  alias LumenViae.Rosary.Library

  @sections "version,updated_at,groups,chants,feasts,months,occasions"
  @empty %{"chants" => [], "groups" => []}

  defp attributes(query) do
    build_conn()
    |> get_v2("/chant-library?fields[chant_library]=" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes"])
  end

  test "missing, en or a language not served: the English document, unchanged" do
    english = attributes(@sections)

    for lang <- ["en", "EN", "fr", "", "spanish"] do
      assert attributes(@sections <> "&lang=" <> lang) == english, lang
    end

    stamp = Library.stamp(:chant_library)
    assert english["version"] == stamp.version
    assert english["updated_at"] == DateTime.to_iso8601(stamp.updated_at)

    for section <- ~w(groups chants feasts months occasions) do
      assert english[section] == Library.sections(:chant_library)[section], section
    end

    for lang <- ["", "&lang=en", "&lang=fr"] do
      assert attributes("translations" <> lang) == %{"translations" => @empty}, lang
    end
  end

  test "es: the Spanish names in translations, every other section the English" do
    english = attributes(@sections)
    spanish = attributes(@sections <> ",translations&lang=es")

    assert spanish["translations"] == Jason.decode!(Jason.encode!(Spanish.translation()))

    assert %{"title" => "Salve Regina", "setting" => "Melodía sencilla"} =
             Enum.find(spanish["translations"]["chants"], &(&1["id"] == "salve_regina_simple"))

    assert %{"title" => "Ven, Espíritu Santo", "setting" => "Canto breve"} =
             Enum.find(spanish["translations"]["chants"], &(&1["id"] == "veni_sancte_reple"))

    assert %{"title" => "Alma de Cristo", "setting" => nil} =
             Enum.find(spanish["translations"]["chants"], &(&1["id"] == "anima_christi"))

    assert %{"title" => "El Rosario en latín"} =
             Enum.find(spanish["translations"]["groups"], &(&1["id"] == "rosary"))

    assert length(spanish["translations"]["chants"]) == length(english["chants"])
    assert length(spanish["translations"]["groups"]) == length(english["groups"])

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

    refute DateTime.compare(
             Current.stamp("es").updated_at,
             Library.stamp(:chant_library).updated_at
           ) ==
             :lt

    assert attributes("version,updated_at,translations&lang=es-MX") ==
             attributes("version,updated_at,translations&lang=es")
  end

  test "the bare request with es is the Spanish version and date alone" do
    attributes =
      build_conn()
      |> get_v2("/chant-library?lang=es")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
    assert attributes["version"] == Current.stamp("es").version
  end
end
