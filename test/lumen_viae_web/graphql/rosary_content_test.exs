defmodule LumenViaeWeb.Graphql.RosaryContentTest do
  @moduledoc """
  GraphQL's `rosaryContent`: the same document as
  `GET /api/v2/rosary-content`, its sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.RosaryContent.Current
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
end
