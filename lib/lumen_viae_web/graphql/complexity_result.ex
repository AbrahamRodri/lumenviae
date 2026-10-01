defmodule LumenViaeWeb.Graphql.ComplexityResult do
  @moduledoc """
  Absinthe's complexity check, with a stable `code` on what it refuses.

  The stock phase answers only a message ("... is too complex ..."), and a
  client cannot branch on prose. This runs it unchanged and stamps each
  error it raised with `code: "too_complex"`: the client's own request is
  too large, so retrying it as it is will not help.
  """
  use Absinthe.Phase

  alias Absinthe.Phase.Document.Complexity

  # Absinthe's own defaults for a phase that stops the document, which the
  # stock pipeline supplies and a replacement phase has to supply itself.
  @abort [jump_phases: true, result_phase: Absinthe.Phase.Document.Result]

  @impl Absinthe.Phase
  def run(blueprint, options \\ []) do
    case Complexity.Result.run(blueprint, Keyword.merge(@abort, options)) do
      {:ok, blueprint} -> {:ok, blueprint}
      {:jump, blueprint, phase} -> {:jump, stamp(blueprint), phase}
      {:error, blueprint} -> {:error, stamp(blueprint)}
    end
  end

  defp stamp(blueprint) do
    update_in(blueprint.execution.validation_errors, fn errors ->
      Enum.map(errors, fn
        %{phase: Complexity.Result} = error ->
          %{error | extra: Map.put(error.extra, :code, "too_complex")}

        error ->
          error
      end)
    end)
  end
end
