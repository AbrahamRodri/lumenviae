defmodule LumenViaeWeb.API.MeditationSetSpanishTest do
  @moduledoc """
  The v1 `GET /api/meditation-sets/:id?lang=es` the iPhone app reads: the
  set's meditations that have Spanish, in `translations`, laid over the
  English by id. Without `lang` the response is exactly what it was, with
  no `translations` key; the meditations and their recordings stay
  English in every language.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation.Spanish

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

  # audio_expires_at is the moment of the request; everything else is the set.
  defp show(conn, set, query) do
    conn
    |> get("/api/meditation-sets/#{set.id}" <> query)
    |> json_response(200)
    |> Map.fetch!("data")
    |> Map.delete("audio_expires_at")
  end

  test "without lang: no translations key, the set as before", %{conn: conn, set: set} do
    english = show(conn, set, "")

    refute Map.has_key?(english, "translations")

    assert Enum.map(english["meditations"], & &1["title"]) ==
             ["The Annunciation", "The Visitation", "Untranslated"]
  end

  test "lang=es: the Spanish in translations, everything else unchanged", %{
    conn: conn,
    set: set,
    meditations: [one, two, _three]
  } do
    english = show(conn, set, "")
    spanish = show(build_conn(), set, "?lang=es")

    assert spanish["translations"] == [
             %{
               "id" => one.id,
               "title" => "La Anunciación",
               "content" => "La Anunciación, en español."
             },
             %{
               "id" => two.id,
               "title" => "La Visitación",
               "content" => "La Visitación, en español.",
               "ai_translated" => true
             }
           ]

    assert Map.delete(spanish, "translations") == english
  end

  test "lang=en, or a language not served: translations empty", %{conn: conn, set: set} do
    english = show(conn, set, "")

    for lang <- ["en", "fr"] do
      served = show(build_conn(), set, "?lang=" <> lang)
      assert served["translations"] == []
      assert Map.delete(served, "translations") == english
    end
  end

  test "an English edit falls back to English", %{conn: conn, set: set, meditations: [one | _]} do
    {:ok, _} = Rosary.update_meditation(one, %{content: "Changed English."}, actor: admin())

    ids = conn |> show(set, "?lang=es") |> Map.fetch!("translations") |> Enum.map(& &1["id"])
    refute one.id in ids
  end

  test "a missing set is still not found with lang", %{conn: conn} do
    assert conn |> get("/api/meditation-sets/999999999?lang=es") |> json_response(404)
  end
end
