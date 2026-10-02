defmodule LumenViaeWeb.API.RetiredVoicesAPITest do
  @moduledoc """
  What a client sees of a retired voice and of a voice borrowing another's
  spoken-Rosary recordings: the production line-up since Frederick.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]

  alias LumenViae.Rosary
  alias LumenViae.Rosary.{PrayerAudio, Voices}

  setup do
    put_env([
      {:lumen_viae, :narration_voices,
       [
         %{
           slug: "frederick",
           name: "Male",
           eleven_labs_voice_id: "fr",
           model_id: "eleven_v4",
           rosary_audio_from: %{
             prayer: "male",
             announcement: "male",
             verse: "male",
             book: "female"
           },
           default: true
         },
         %{slug: "female", name: "Female", eleven_labs_voice_id: "f"},
         %{
           slug: "male",
           name: "Male (original)",
           eleven_labs_voice_id: "m",
           hidden: true,
           replaced_by: "frederick"
         }
       ]},
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Retired Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(%{content: "M", mystery_id: mystery.id, audio_url: "m.mp3"},
        actor: admin()
      )

    for slug <- ["male", "female", "frederick"] do
      {:ok, _} = Rosary.record_narration(meditation, slug, "voices/#{slug}/m.mp3", actor: admin())
    end

    %{meditation: meditation}
  end

  test "GET /api/voices offers only the current voices", %{conn: conn} do
    data = conn |> get("/api/voices") |> json_response(200) |> Map.fetch!("data")

    assert Enum.map(data, &{&1["slug"], &1["name"], &1["default"]}) == [
             {"frederick", "Male", true},
             {"female", "Female", false}
           ]
  end

  test "a device still asking for the retired voice hears its successor", %{
    conn: conn,
    meditation: meditation
  } do
    data =
      conn
      |> get("/api/meditations/#{meditation.id}/audio?voice=male")
      |> json_response(200)
      |> Map.fetch!("data")

    assert data["voice"] == "frederick"
    assert data["audio_url"] =~ "voices/frederick/m.mp3"
  end

  test "the spoken Rosary in Frederick is Marc Aurele's, the Prayer Book Arabella's", %{
    conn: conn
  } do
    data =
      conn
      |> get("/api/rosary/audio?voice=frederick&include=prayers,verses,book")
      |> json_response(200)
      |> Map.fetch!("data")

    frederick = Voices.get("frederick")
    male = Voices.get("male")
    hail_mary = Enum.find(PrayerAudio.clips([:prayer]), &(&1.name == "hail_mary"))

    assert data["voice"] == "frederick"
    assert data["version"] == PrayerAudio.version(frederick, PrayerAudio.clips())
    assert data["prayers"]["hail_mary"]["file"] == PrayerAudio.filename(male, hail_mary)
    assert data["prayers"]["hail_mary"]["audio_url"] =~ "voices/male/rosary/prayers/"

    [verse | _] = data["verses"] |> Map.values() |> hd()
    assert verse["audio_url"] =~ "voices/male/rosary/verses/"

    [book | _] = Map.values(data["book"])
    assert book["audio_url"] =~ "voices/female/rosary/books/"
  end

  test "the default spoken Rosary and the retired slug are both Frederick's", %{conn: conn} do
    default = conn |> get("/api/rosary/audio") |> json_response(200) |> Map.fetch!("data")

    retired =
      conn |> get("/api/rosary/audio?voice=male") |> json_response(200) |> Map.fetch!("data")

    assert default["voice"] == "frederick"
    assert retired["voice"] == "frederick"
    assert retired["version"] == default["version"]
  end
end
