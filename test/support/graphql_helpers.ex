defmodule LumenViaeWeb.GraphqlHelpers do
  @moduledoc """
  Runs a GraphQL document against `/api/graphql` the way a client does: a
  JSON body over POST, through the router and the `:graphql` pipeline,
  rather than calling `Absinthe.run/3` and skipping both.
  """
  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint LumenViaeWeb.Endpoint

  @doc """
  Posts `query` with `variables` and returns the conn.
  """
  def post_graphql(conn, query, variables \\ %{}) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/api/graphql", Jason.encode!(%{query: query, variables: variables}))
  end

  @doc """
  Posts `query` and returns the decoded body, asserting a 200 - which a
  GraphQL server answers even when the body carries errors.
  """
  def graphql(conn, query, variables \\ %{}) do
    conn |> post_graphql(query, variables) |> json_response(200)
  end
end
