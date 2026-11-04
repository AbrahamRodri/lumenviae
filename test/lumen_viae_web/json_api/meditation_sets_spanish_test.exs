defmodule LumenViaeWeb.JsonApi.MeditationSetsSpanishTest do
  @moduledoc """
  `GET /api/v2/meditation-sets/:id?lang=es` and the list with `lang=es`:
  the set's meditations that have Spanish, in `translations`, laid over the
  English by id. Without `lang` (or with `en`, or a language not served)
  every set is exactly what it was, `translations` empty. A meditation
  whose English changed after its Spanish was made falls back to English.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation.Spanish

  @fields "fields[meditation_set]=name,category,description,labels,author,source,artwork"

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "ES Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: 100 + rem(System.unique_integer([:positive]), 100_000),
          scripture_reference: "Luke 1:26-38"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "ES Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    meditations =
      for {title, order} <- [{"The Annunciation", 1}, {"The Visitation", 2}, {"Untranslated", 3}] do
        {:ok, meditation} =
          Rosary.create_meditation(
            %{title: title, content: "#{title}, the English.", mystery_id: mystery.id},
            actor: admin()
          )

        {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
        meditation
      end

    [one, two, _three] = meditations

    entries = %{
      "#{one.id}" => %{
        "title" => "La Anunciación",
        "content" => "La Anunciación, en español.",
        "english" => Spanish.fingerprint(one.title, one.content)
      },
      "#{two.id}" => %{
        "title" => "La Visitación",
        "content" => "La Visitación, en español.",
        "english" => Spanish.fingerprint(two.title, two.content),
        "ai_translated" => true
      }
    }

    previous = Application.get_env(:lumen_viae, Spanish)
    Application.put_env(:lumen_viae, Spanish, entries: entries)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:lumen_viae, Spanish, previous),
        else: Application.delete_env(:lumen_viae, Spanish)
    end)

    %{set: set, meditations: meditations}
  end

  defp attributes(conn, set, query) do
    conn
    |> get_v2("/meditation-sets/#{set.id}?" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes"])
  end

  test "missing, en or a language not served: the set as it was", %{conn: conn, set: set} do
    english = attributes(conn, set, @fields)

    for lang <- ["en", "fr", "", "spanish"] do
      assert attributes(build_conn(), set, @fields <> "&lang=" <> lang) == english, lang
    end

    refute Map.has_key?(english, "translations")

    for lang <- ["", "&lang=en", "&lang=fr"] do
      assert attributes(build_conn(), set, "fields[meditation_set]=translations" <> lang) ==
               %{"translations" => []}
    end
  end

  test "es: the Spanish in prayer order, every other field the English",
       %{conn: conn, set: set, meditations: [one, two, _three]} do
    english = attributes(conn, set, @fields)
    spanish = attributes(build_conn(), set, @fields <> ",translations&lang=es")

    assert spanish["translations"] == [
             %{"id" => one.id, "title" => "La Anunciación", "content" => "La Anunciación, en español."},
             %{
               "id" => two.id,
               "title" => "La Visitación",
               "content" => "La Visitación, en español.",
               "ai_translated" => true
             }
           ]

    assert Map.delete(spanish, "translations") == english

    assert attributes(build_conn(), set, "fields[meditation_set]=translations&lang=es-MX") ==
             attributes(build_conn(), set, "fields[meditation_set]=translations&lang=es")
  end

  test "an English edit puts that meditation back in English",
       %{conn: conn, set: set, meditations: [one, two, _three]} do
    {:ok, _} = Rosary.update_meditation(one, %{content: "Edited English."}, actor: admin())

    assert [%{"id" => id}] = attributes(conn, set, "fields[meditation_set]=translations&lang=es")["translations"]
    assert id == two.id
  end

  test "the included meditations are the English in every language", %{conn: conn, set: set} do
    query = "include=set_memberships.meditation&" <> @fields

    english = conn |> get_v2("/meditation-sets/#{set.id}?" <> query) |> v2_response(200)
    spanish = build_conn() |> get_v2("/meditation-sets/#{set.id}?" <> query <> "&lang=es") |> v2_response(200)

    assert english["included"] == spanish["included"]
  end

  test "the list carries each set's Spanish with lang=es", %{conn: conn, set: set} do
    sets =
      conn
      |> get_v2("/meditation-sets?category=joyful&lang=es&fields[meditation_set]=name,translations")
      |> v2_response(200)
      |> Map.fetch!("data")

    ours = Enum.find(sets, &(&1["id"] == to_string(set.id)))
    assert length(ours["attributes"]["translations"]) == 2
  end
end
