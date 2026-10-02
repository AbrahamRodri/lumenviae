defmodule LumenViaeWeb.Graphql.AuthorizationTest do
  @moduledoc """
  GraphQL is anonymous. It is served off the browser pipeline, with no
  session and no CSRF token, so it never reads the console's cookie: every
  operation runs with no actor and gets exactly what the public may.
  The one mutation is the public completion write; nothing else can be
  written through it, signed in or not.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary

  test "recordCompletion is the only mutation" do
    mutations =
      LumenViaeWeb.GraphqlSchema
      |> Absinthe.Schema.lookup_type(:mutation)
      |> Map.fetch!(:fields)
      |> Map.keys()
      |> List.delete(:__typename)

    assert mutations == [:record_completion]
  end

  test "a write the schema does not offer is refused before anything runs", %{conn: conn} do
    body =
      graphql(conn, """
      mutation { createMeditation(input: {content: "x"}) { result { id } } }
      """)

    assert %{"errors" => [%{"code" => "invalid_document"} | _]} = body
    refute body["data"]
  end

  test "an admin's session cookie does not make GraphQL an admin", %{conn: conn} do
    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "Empty #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    conn = log_in_admin(conn)

    body =
      graphql(conn, "query($id: ID!) { meditationSet(id: $id) { id } }", %{
        "id" => to_string(set.id)
      })

    assert %{"data" => %{"meditationSet" => nil}} = body
  end
end
