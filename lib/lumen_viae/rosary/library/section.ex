defmodule LumenViae.Rosary.Library.Section do
  @moduledoc """
  One section of a `LumenViae.Rosary.Library` document: `document` and
  `section` name it (`:prayer_book`, `"prayers"`). The section was cast to
  its type once, as `Library` compiled, so a request only hands it over.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Library

  @impl true
  def calculate(records, opts, _context) do
    value = Library.served(opts[:document], opts[:section])

    Enum.map(records, fn _record -> value end)
  end

  @doc """
  A cast section as plain data again, string keys throughout, to compare
  with what the file holds.
  """
  @spec plain(term) :: term
  def plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  def plain(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {to_string(key), plain(value)} end)
  end

  def plain(value), do: value
end
