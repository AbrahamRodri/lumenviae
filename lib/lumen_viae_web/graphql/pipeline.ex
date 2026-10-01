defmodule LumenViaeWeb.Graphql.Pipeline do
  @moduledoc """
  Absinthe's default pipeline for `/api/graphql`, with
  `LumenViaeWeb.Graphql.UpstreamBudget` run straight after the complexity
  check, so an over-budget document is refused before any resolver runs.
  """

  def pipeline(config, options) do
    config
    |> Absinthe.Plug.default_pipeline(options)
    |> Absinthe.Pipeline.insert_after(
      Absinthe.Phase.Document.Complexity.Result,
      {LumenViaeWeb.Graphql.UpstreamBudget, options}
    )
  end
end
