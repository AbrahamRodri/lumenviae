defmodule LumenViaeWeb.JsonApi.ConsecrationSpanishTest do
  @moduledoc """
  `GET /api/v2/consecration?lang=es`: the Consecration with its Spanish in
  `translations`. Without `lang` (or with `en`, or a language not served)
  the document is exactly what it was before Spanish, `translations` empty.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.Consecration.Current
  alias LumenViae.Rosary.Consecration.Spanish
  alias LumenViae.Rosary.Library

  @sections "version,updated_at,phases,days,prayers,feasts"
  @empty %{"phases" => [], "days" => [], "prayers" => [], "feasts" => []}

  defp attributes(query) do
    build_conn()
    |> get_v2("/consecration?fields[consecration]=" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes"])
  end

  test "missing, en or a language not served: the English document, unchanged" do
    english = attributes(@sections)

    for lang <- ["en", "EN", "fr", "", "spanish"] do
      assert attributes(@sections <> "&lang=" <> lang) == english, lang
    end

    stamp = Library.stamp(:consecration)
    assert english["version"] == stamp.version
    assert english["updated_at"] == DateTime.to_iso8601(stamp.updated_at)

    for lang <- ["", "&lang=en", "&lang=fr"] do
      assert attributes("translations" <> lang) == %{"translations" => @empty}, lang
    end
  end

  test "es: the Spanish in translations, every other section the English" do
    english = attributes(@sections)
    spanish = attributes(@sections <> ",translations&lang=es")

    assert spanish["translations"] == Jason.decode!(Jason.encode!(Spanish.translation()))

    day = Enum.find(spanish["translations"]["days"], &(&1["number"] == 1))
    assert %{"title" => "El espíritu del mundo", "ai_translated" => true} = day

    assert %{"id" => "glory_be", "title" => "Gloria al Padre"} =
             Enum.find(spanish["translations"]["prayers"], &(&1["id"] == "glory_be"))

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
      |> get_v2("/consecration?lang=es")
      |> v2_response(200)
      |> get_in(["data", "attributes"])

    assert Map.keys(attributes) |> Enum.sort() == ["updated_at", "version"]
    assert attributes["version"] == Current.stamp("es").version
  end
end
