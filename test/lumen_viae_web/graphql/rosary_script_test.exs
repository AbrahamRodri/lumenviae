defmodule LumenViaeWeb.Graphql.RosaryScriptTest do
  @moduledoc """
  GraphQL's `rosaryScript` and the content document's `script` section:
  the same expansion and the same templates as `/api/v2`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.{Content, PrayerAudio}

  test "rosaryScript is the server's expansion, step for step", %{conn: conn} do
    body =
      graphql(conn, """
      {
        rosaryScript(category: "seven_sorrows", style: "scriptural", orders: "2,3") {
          category style extras orders
          steps { kind name mystery caption phase decade bead place pauseMs }
        }
      }
      """)

    refute body["errors"]

    %{"orders" => [2, 3], "extras" => [], "steps" => steps} = body["data"]["rosaryScript"]

    expected =
      PrayerAudio.script("seven_sorrows", [2, 3], style: :scriptural)
      |> Enum.map(fn step ->
        %{
          "kind" => Atom.to_string(step.kind),
          "name" => step.name,
          "mystery" => step.mystery,
          "caption" => step.caption,
          "phase" => Atom.to_string(step.phase),
          "decade" => step.decade,
          "bead" => step.bead,
          "place" => step.place,
          "pauseMs" => step.pause_ms
        }
      end)

    assert steps == expected
  end

  test "an unknown value is an invalid_argument naming the field and the valid values",
       %{conn: conn} do
    body = graphql(conn, ~s|{ rosaryScript(category: "joyful", style: "sung") { id } }|)

    assert body["data"] == %{"rosaryScript" => nil}

    assert [%{"code" => "invalid_argument", "fields" => ["style"], "message" => message}] =
             body["errors"]

    assert message == "style must be one of: meditation, scriptural, plain"
  end

  test "the content document's script section carries the templates", %{conn: conn} do
    body =
      graphql(conn, """
      {
        rosaryContent {
          script {
            styles
            rosary { categories takesExtras decade { kind prayerId caption bead perBead style pauseMs } strand { beads gloryBeBead } }
            chaplet { categories strand { beads labels { gloryBe } } }
            closingExtras { id title shortTitle detail steps { prayerId caption } }
            pendant { place name }
            headings { opening closing }
          }
        }
      }
      """)

    refute body["errors"]

    script = body["data"]["rosaryContent"]["script"]

    assert script["styles"] == Content.script()["styles"]
    assert script["rosary"]["strand"] == %{"beads" => 56, "gloryBeBead" => 11}
    assert script["chaplet"]["strand"] == %{"beads" => 57, "labels" => %{"gloryBe" => "Glory Be"}}
    assert Enum.map(script["closingExtras"], & &1["id"]) == ~w(holy_father memorare st_michael)

    assert script["headings"] == %{
             "opening" => "The Opening Prayers",
             "closing" => "The Closing Prayers"
           }

    assert %{"kind" => "verse", "perBead" => true, "style" => "scriptural", "bead" => nil} =
             Enum.find(script["rosary"]["decade"], &(&1["kind"] == "verse"))
  end
end
