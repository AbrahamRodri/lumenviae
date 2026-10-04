defmodule LumenViaeWeb.Graphql.RosaryContentTest do
  @moduledoc """
  GraphQL's `rosaryContent`: the same document as
  `GET /api/v2/rosary-content`, its sections chosen by the selection set.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Content

  test "the version and the date alone", %{conn: conn} do
    assert %{"data" => %{"rosaryContent" => content}} =
             graphql(conn, "{ rosaryContent { id version updatedAt } }")

    assert content == %{
             "id" => "current",
             "version" => Content.version(),
             "updatedAt" => DateTime.to_iso8601(Content.updated_at())
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
end
