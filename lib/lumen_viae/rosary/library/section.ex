defmodule LumenViae.Rosary.Library.Section do
  @moduledoc """
  One section of a `LumenViae.Rosary.Library` document, cast to its type:
  `document` and `section` name it (`:prayer_book`, `"prayers"`), `type`
  is what each of its items is.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Library

  @impl true
  def calculate(records, opts, _context) do
    value = cast!(opts[:type], Library.sections(opts[:document])[opts[:section]])

    Enum.map(records, fn _record -> value end)
  end

  @doc "A section's items, cast to `type`. Raises if the file does not fit it."
  @spec cast!(module, [map]) :: [struct]
  def cast!(type, items) do
    {:ok, cast} = Ash.Type.cast_input({:array, type}, items, nil_items?: false)
    cast
  end
end
