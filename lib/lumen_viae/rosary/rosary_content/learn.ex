defmodule LumenViae.Rosary.RosaryContent.Learn do
  @moduledoc """
  The `learn` and `guided_rosary` sections of
  `LumenViae.Rosary.RosaryContent`: `LumenViae.Rosary.Content`'s How to
  Pray course and "Your First Rosary", cast to their types
  (`Types.RosaryLearn`, `Types.GuidedRosary`). `section` names which.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def init(opts) do
    if opts[:section] in [:learn, :guided_rosary],
      do: {:ok, opts},
      else: {:error, "section must be :learn or :guided_rosary"}
  end

  @impl true
  def calculate(records, opts, _context) do
    value = section(opts[:section])

    Enum.map(records, fn _record -> value end)
  end

  @doc "A section, cast to its type. Raises if the file does not fit it."
  @spec section(:learn | :guided_rosary) :: struct
  def section(:learn), do: cast!(Types.RosaryLearn, Content.learn())
  def section(:guided_rosary), do: cast!(Types.GuidedRosary, Content.guided_rosary())

  defp cast!(type, value) do
    {:ok, cast} = Ash.Type.cast_input(type, value, [])
    cast
  end
end
