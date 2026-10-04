defmodule LumenViae.Rosary.RosaryContent.Script do
  @moduledoc """
  The `script` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content.script/0`'s templates, shaped as
  `LumenViae.Rosary.Types.ScriptTemplates`.
  """
  use Ash.Resource.Calculation

  alias Ash.Type.NewType
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types.ScriptTemplates

  @impl true
  def calculate(records, _opts, _context) do
    constraints = NewType.constraints(ScriptTemplates, [])

    case Ash.Type.cast_input(ScriptTemplates, Content.script(), constraints) do
      {:ok, script} -> Enum.map(records, fn _record -> script end)
      {:error, error} -> {:error, error}
    end
  end
end
