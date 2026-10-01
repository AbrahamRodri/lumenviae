defmodule LumenViaeWeb.Graphql.ErrorHandler do
  @moduledoc """
  AshGraphql's error handler for both domains: the default one, which fills
  variables into messages, plus one change. An error names the fields it
  is about as Ash spells them (`meditation_set_id`), while the client sent
  them as GraphQL spells them (`meditationSetId`). A client matching an
  error to the input it came from would never find it, so `fields` is
  rewritten into the GraphQL spelling.

  Configured on the domains in `config/config.exs`, so the domain modules
  do not name the web layer.
  """

  def handle_error(error, context) do
    error
    |> AshGraphql.DefaultErrorHandler.handle_error(context)
    |> camelize_fields()
  end

  defp camelize_fields(%{fields: fields} = error) when is_list(fields) do
    %{error | fields: Enum.map(fields, &camelize/1)}
  end

  defp camelize_fields(error), do: error

  defp camelize(field) do
    [first | rest] = field |> to_string() |> String.split("_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end
end
