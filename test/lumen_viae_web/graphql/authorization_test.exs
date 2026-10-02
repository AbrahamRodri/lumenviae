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

    query = "query($id: ID!) { meditationSet(id: $id) { id } }"
    variables = %{"id" => to_string(set.id)}

    # The set exists, and an admin outside GraphQL does see it.
    assert {:ok, _} = Rosary.get_meditation_set(set.id, actor: admin())

    as_admin = graphql(log_in_admin(conn), query, variables)
    as_public = graphql(build_conn(), query, variables)

    # Exactly the anonymous answer, with no data and no error that would
    # tell the two apart.
    assert as_admin == %{"data" => %{"meditationSet" => nil}}
    assert as_admin == as_public
  end
end
