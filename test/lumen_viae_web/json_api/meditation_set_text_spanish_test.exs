defmodule LumenViaeWeb.JsonApi.MeditationSetTextSpanishTest do
  @moduledoc """
  A set's own description, source and image alt in Spanish, in
  `set_translation`, with `lang=es`: on `GET /api/v2/meditation-sets/:id`
  (asked for in `fields`), GraphQL's `meditationSet(id:, lang:)` and the
  v1 `GET /api/meditation-sets/:id` the iPhone app reads. Each field falls
  back to English (null) once its English changes; without `lang`
  everything is exactly as before.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.GraphqlHelpers
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation.SetSpanish

  @fields "fields[meditation_set]=name,category,description,labels,author,source,artwork"

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "ES Set Text Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: 100 + rem(System.unique_integer([:positive]), 100_000),
          scripture_reference: "Luke 1:26-38"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{
          name: "ES Set Text #{System.unique_integer([:positive])}",
          category: "joyful",
          description: "Meditations on the Joyful Mysteries.",
          source: "Glories of Mary"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.update_meditation_set_artwork(
        set,
        %{
          "image_key" => "sets/1/8f21c4d9e0b3a7f6.jpg",
          "image_width" => 1600,
          "image_height" => 2400,
          "image_alt" => "Portrait",
          "image_license" => "public_domain"
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        %{title: "The Annunciation", content: "The English.", mystery_id: mystery.id},
        actor: admin()
      )

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())

    put_sets(%{
      "#{set.id}" => %{
        "description" => %{
          "es" => "Meditaciones sobre los misterios gozosos.",
          "english" => SetSpanish.fingerprint("Meditations on the Joyful Mysteries.")
        },
        "source" => %{
          "es" => "Las glorias de María",
          "english" => SetSpanish.fingerprint("Glories of Mary")
        },
        "image_alt" => %{"es" => "Retrato", "english" => SetSpanish.fingerprint("Portrait")}
      }
    })

    %{set: set}
  end

  defp put_sets(entries) do
    previous = Application.get_env(:lumen_viae, SetSpanish)
    Application.put_env(:lumen_viae, SetSpanish, entries: entries)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:lumen_viae, SetSpanish, previous),
        else: Application.delete_env(:lumen_viae, SetSpanish)
    end)
  end

  @spanish %{
    "description" => "Meditaciones sobre los misterios gozosos.",
    "source" => "Las glorias de María",
    "artwork_alt" => "Retrato",
    "ai_translated" => true
  }

  defp attributes(conn, set, query) do
    conn
    |> get_v2("/meditation-sets/#{set.id}?" <> query)
    |> v2_response(200)
    |> get_in(["data", "attributes"])
  end

  defp v1(conn, set, query) do
    conn
    |> get("/api/meditation-sets/#{set.id}" <> query)
    |> json_response(200)
    |> Map.fetch!("data")
    |> Map.delete("audio_expires_at")
  end

  describe "v2" do
    test "lang=es: the set's own Spanish in set_translation, the rest unchanged", %{
      conn: conn,
      set: set
    } do
      english = attributes(conn, set, @fields)
      spanish = attributes(build_conn(), set, @fields <> ",set_translation&lang=es")

      assert spanish["set_translation"] == @spanish
      assert Map.delete(spanish, "set_translation") == english
    end

    test "missing, en or a language not served: null, and absent from the defaults", %{
      conn: conn,
      set: set
    } do
      refute Map.has_key?(attributes(conn, set, ""), "set_translation")

      for lang <- ["", "en", "fr"] do
        served = attributes(build_conn(), set, @fields <> ",set_translation&lang=" <> lang)
        assert served["set_translation"] == nil, lang
      end
    end

    test "an English edit falls back to English, field by field", %{conn: conn, set: set} do
      {:ok, _} =
        Rosary.update_meditation_set(set, %{description: "Changed English."}, actor: admin())

      spanish = attributes(conn, set, @fields <> ",set_translation&lang=es")
      assert spanish["set_translation"] == %{@spanish | "description" => nil}
    end

    test "a set with no Spanish of its own is null", %{conn: conn, set: set} do
      put_sets(%{})

      assert attributes(conn, set, "fields[meditation_set]=set_translation&lang=es") == %{
               "set_translation" => nil
             }
    end
  end

  test "GraphQL: setTranslation with lang: es, null without", %{set: set} do
    query = fn args ->
      graphql(build_conn(), """
      { meditationSet(id: #{set.id}#{args}) { setTranslation { description source artworkAlt aiTranslated } } }
      """)
    end

    assert get_in(query.(~s|, lang: "es"|), ["data", "meditationSet", "setTranslation"]) == %{
             "description" => "Meditaciones sobre los misterios gozosos.",
             "source" => "Las glorias de María",
             "artworkAlt" => "Retrato",
             "aiTranslated" => true
           }

    assert get_in(query.(""), ["data", "meditationSet", "setTranslation"]) == nil
  end

  describe "v1" do
    test "lang=es: set_translation beside translations, with image_alt", %{
      conn: conn,
      set: set
    } do
      english = v1(conn, set, "")
      spanish = v1(build_conn(), set, "?lang=es")

      assert spanish["set_translation"] == %{
               "description" => "Meditaciones sobre los misterios gozosos.",
               "source" => "Las glorias de María",
               "image_alt" => "Retrato",
               "ai_translated" => true
             }

      assert Map.drop(spanish, ["translations", "set_translation"]) == english
    end

    test "without lang: no set_translation key; another language: null", %{conn: conn, set: set} do
      refute Map.has_key?(v1(conn, set, ""), "set_translation")
      assert Map.fetch!(v1(build_conn(), set, "?lang=en"), "set_translation") == nil
    end
  end
end
