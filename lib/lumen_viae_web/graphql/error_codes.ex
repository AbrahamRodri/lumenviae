defmodule LumenViaeWeb.Graphql.ErrorCodes do
  @moduledoc """
  Gives every error in a response a `code`, so a client always has
  something to branch on and never has to read the message.

  Most errors already carry one: the domains' own, AshGraphql's, the
  completion guard's, the complexity and upstream-budget refusals. Two
  kinds arrive without one, and are told apart by whether they have a
  `path`, which only an error raised while resolving a field does:

    * `internal_error` - something failed on the server while resolving a
      field (AshGraphql's "something went wrong", with an id in the log).
      Retry later.
    * `invalid_document` - the document itself was rejected before
      anything ran: a syntax error, an unknown field, a missing variable.
      The client's own mistake; retrying it unchanged will not help.

  Runs after Absinthe's result phase, on the formatted errors.
  """
  use Absinthe.Phase

  @impl Absinthe.Phase
  def run(%{result: %{errors: errors} = result} = blueprint, _options) when is_list(errors) do
    {:ok, %{blueprint | result: %{result | errors: Enum.map(errors, &with_code/1)}}}
  end

  def run(blueprint, _options), do: {:ok, blueprint}

  defp with_code(%{code: _} = error), do: error
  defp with_code(%{path: [_ | _]} = error), do: Map.put(error, :code, "internal_error")
  defp with_code(error), do: Map.put(error, :code, "invalid_document")
end
