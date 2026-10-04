defmodule LumenViaeWeb.Graphql.RosaryContentTest do
  @moduledoc """
  GraphQL's `rosaryContent`: the same document as
  `GET /api/v2/rosary-content`, its sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Labels, as: LabelsSection
  alias LumenViae.Rosary.RosaryContent.Schedule

  test "the version and the date alone", %{conn: conn} do
    assert %{"data" => %{"rosaryContent" => content}} =
             graphql(conn, "{ rosaryContent { id version updatedAt } }")

    %{version: version, updated_at: updated_at} = Current.stamp()

    assert content == %{
             "id" => "current",
             "version" => version,
             "updatedAt" => DateTime.to_iso8601(updated_at)
           }
  end

  test "the prayers, in the order they are said, in both languages", %{conn: conn} do
    body =
      graphql(conn, """
      { rosaryContent { prayers { id group title { en la } text { en la } } } }
      """)

    refute body["errors"]

    prayers = get_in(body, ["data", "rosaryContent", "prayers"])

    assert prayers == Content.prayers()
  end

  test "the schedule, as the JSON:API serves it", %{conn: conn} do
    body =
      graphql(conn, """
      { rosaryContent { schedule {
          default seasonsFrom seasonsThrough
          seasons { season startsOn endsOn }
          schedules {
            id grid
            weekdays { monday tuesday wednesday thursday friday saturday }
            sunday { advent lent ordinary }
            days { category daysPrayed words }
          }
      } } }
      """)

    refute body["errors"]

    section = Schedule.section(Schedule.current_year())
    schedule = get_in(body, ["data", "rosaryContent", "schedule"])

    assert schedule["default"] == section["default"]
    assert schedule["seasonsFrom"] == section["seasons_from"]
    assert schedule["seasonsThrough"] == section["seasons_through"]

    assert schedule["seasons"] ==
             Enum.map(
               section["seasons"],
               &%{
                 "season" => &1["season"],
                 "startsOn" => &1["starts_on"],
                 "endsOn" => &1["ends_on"]
               }
             )

    assert schedule["schedules"] ==
             Enum.map(section["schedules"], fn rules ->
               %{
                 "id" => rules["id"],
                 "grid" => rules["grid"],
                 "weekdays" => rules["weekdays"],
                 "sunday" => rules["sunday"],
                 "days" =>
                   Enum.map(
                     rules["days"],
                     &%{
                       "category" => &1["category"],
                       "daysPrayed" => &1["days_prayed"],
                       "words" => &1["words"]
                     }
                   )
               }
             end)
  end

  test "the How to Pray course and the guided Rosary", %{conn: conn} do
    body =
      graphql(conn, """
      { rosaryContent {
          learn {
            intro
            lessons { id number title sections { shows prayerIds items { numeral title text } } }
            shelves { id readings { id doors { kind target title note } tables { title rows { label value } } } }
            prayerCounts { prayerId count }
          }
          guidedRosary { firstKeptStep parts rosaries { category steps { part place prayerIds decade } } }
      } }
      """)

    refute body["errors"]

    content = get_in(body, ["data", "rosaryContent"])
    learn = Content.learn()

    assert content["learn"]["intro"] == learn["intro"]

    assert Enum.map(content["learn"]["lessons"], & &1["title"]) ==
             Enum.map(learn["lessons"], & &1["title"])

    assert content["learn"]["prayerCounts"] ==
             Enum.map(
               learn["prayer_counts"],
               &%{"prayerId" => &1["prayer_id"], "count" => &1["count"]}
             )

    assert content["guidedRosary"]["parts"] == Content.guided_rosary()["parts"]
    assert Enum.map(content["guidedRosary"]["rosaries"], &length(&1["steps"])) == [75, 75, 75, 75]
  end

  test "the quotes, the milestones and the labels, as the JSON:API serves them", %{conn: conn} do
    body =
      graphql(conn, """
      { rosaryContent {
          quotes { rotation { homeOffset afterPrayerOffsetDivisor } items { text author source } }
          milestones { days meaning icon blessing }
          labels { labels { id name } kinds { label icon title description } }
      } }
      """)

    refute body["errors"]

    content = get_in(body, ["data", "rosaryContent"])
    quotes = Content.quotes()

    assert content["quotes"]["rotation"] == %{
             "homeOffset" => quotes["rotation"]["home_offset"],
             "afterPrayerOffsetDivisor" => quotes["rotation"]["after_prayer_offset_divisor"]
           }

    assert content["quotes"]["items"] == quotes["items"]
    assert content["milestones"] == Content.milestones()
    assert content["labels"] == LabelsSection.section()
  end

  test "the reminders and the forms", %{conn: conn} do
    body =
      graphql(conn, """
      { rosaryContent {
          reminders {
            fallbackGroup weekLength
            groups { id messages { title body } }
            intentions { id rawValue name detail groups }
          }
          forms {
            holyAudioValue
            forms { id name recordedAs kicker subtitle detail about }
            choices { id title icon options { form value name note } }
            offered { form whenAloud whenSilent }
            rows { form whenAloud whenSilent }
            rowTitles { id title }
          }
      } }
      """)

    refute body["errors"]

    content = get_in(body, ["data", "rosaryContent"])
    reminders = Content.reminders()
    forms = Content.forms()

    assert content["reminders"]["fallbackGroup"] == reminders["fallback_group"]
    assert content["reminders"]["weekLength"] == reminders["week_length"]
    assert content["reminders"]["groups"] == reminders["groups"]

    assert Enum.map(content["reminders"]["intentions"], & &1["groups"]) ==
             Enum.map(reminders["intentions"], & &1["groups"])

    assert content["forms"]["holyAudioValue"] == forms["holy_audio_value"]

    assert Enum.map(content["forms"]["forms"], & &1["recordedAs"]) ==
             Enum.map(forms["forms"], & &1["recorded_as"])

    assert content["forms"]["choices"] == forms["choices"]
    assert content["forms"]["rowTitles"] == forms["row_titles"]

    assert Enum.map(content["forms"]["offered"], &{&1["form"], &1["whenAloud"], &1["whenSilent"]}) ==
             Enum.map(forms["offered"], &{&1["form"], &1["when_aloud"], &1["when_silent"]})
  end
end
