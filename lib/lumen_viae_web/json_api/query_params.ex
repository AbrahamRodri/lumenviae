defmodule LumenViaeWeb.JsonApi.QueryParams do
  @moduledoc """
  Holds `/api/v2`'s query parameters to what docs/JSON_API.md promises,
  where AshJsonApi 1.7 cannot be configured to.

    * **No includes on the list of sets.** `include` is allowed on
      `MeditationSet` as a whole, and AshJsonApi has no per-route includes,
      so the list would carry them too: one GET returning every visible
      set's meditations and mysteries, with every recording signed when
      `fields[meditation]` asks for it. A client reads the list for the
      shelf and asks `GET /api/v2/meditation-sets/:id` for the set it opens,
      as v1 does. A list request that names `include` is refused with a
      JSON:API 400 (`invalid_includes`), rather than silently answered
      without its includes, so a client learns the rule the first time.
    * **No sorting, filtering or paging of what is included.** AshJsonApi
      honours `sort_included` even though every resource says
      `derive_sort? false` (it reads the option under the wrong key), so
      `sort_included[set_memberships]=-order` would reverse a set's prayer
      order. `sort_included`, `filter_included` and `included_page` are
      dropped before AshJsonApi sees them, so they are ignored, as `sort`,
      `filter` and `page` are.

  Matched on `path_info`, which has no empty segments, so a trailing or
  doubled slash reaches the same rule as the route it reaches.
  """
  @behaviour Plug

  import Plug.Conn

  # The routes, under /api/v2, that return a list of sets. Shared with
  # LumenViaeWeb.JsonApi.OpenApi, which leaves `include` out of their
  # description.
  @lists_without_includes [["meditation-sets"]]

  @dropped ~w(sort_included filter_included included_page)

  @doc """
  The paths, relative to `/api/v2`, of the routes that take no `include`.
  """
  def lists_without_includes, do: Enum.map(@lists_without_includes, &("/" <> Path.join(&1)))

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = fetch_query_params(conn)

    if list_without_includes?(conn) and Map.has_key?(conn.query_params, "include") do
      refuse_include(conn)
    else
      drop_included_params(conn)
    end
  end

  defp list_without_includes?(%{path_info: ["api", "v2" | rest]}),
    do: rest in @lists_without_includes

  defp list_without_includes?(_conn), do: false

  defp drop_included_params(conn) do
    %{
      conn
      | query_params: Map.drop(conn.query_params, @dropped),
        params: Map.drop(conn.params, @dropped)
    }
  end

  defp refuse_include(conn) do
    body = %{
      errors: [
        %{
          status: "400",
          code: "invalid_includes",
          title: "InvalidIncludes",
          detail:
            "The list of sets includes nothing. Ask GET /api/v2/meditation-sets/:id for a set's meditations.",
          source: %{parameter: "include"}
        }
      ],
      jsonapi: %{version: "1.0"}
    }

    conn
    |> put_resp_content_type("application/vnd.api+json", nil)
    |> send_resp(400, Jason.encode!(body))
    |> halt()
  end
end
