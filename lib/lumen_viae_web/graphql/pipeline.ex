defmodule LumenViaeWeb.Graphql.Pipeline do
  @moduledoc """
  Absinthe's default pipeline for `/api/graphql`, with three changes:

    * the complexity check is `LumenViaeWeb.Graphql.ComplexityResult`, the
      stock one with a `code` on what it refuses
    * `LumenViaeWeb.Graphql.UpstreamBudget` runs straight after it, so an
      over-budget document is refused before any resolver runs
    * `LumenViaeWeb.Graphql.ErrorCodes` runs after the result is built, so
      every error in a response carries a `code`
  """

  alias Absinthe.Phase.Document

  def pipeline(config, options) do
    config
    |> Absinthe.Plug.default_pipeline(options)
    |> Absinthe.Pipeline.replace(
      Document.Complexity.Result,
      {LumenViaeWeb.Graphql.ComplexityResult, options}
    )
    |> Absinthe.Pipeline.insert_after(
      LumenViaeWeb.Graphql.ComplexityResult,
      {LumenViaeWeb.Graphql.UpstreamBudget, options}
    )
    |> Absinthe.Pipeline.insert_after(Document.Result, LumenViaeWeb.Graphql.ErrorCodes)
  end
end
