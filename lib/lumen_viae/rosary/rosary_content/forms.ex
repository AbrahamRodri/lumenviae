defmodule LumenViae.Rosary.RosaryContent.Forms do
  @moduledoc """
  The `forms` section of `LumenViae.Rosary.RosaryContent`:
  `LumenViae.Rosary.Content`'s names and notes for the Rosary's forms and
  its two choices, shaped as `LumenViae.Rosary.Types.RosaryForms`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Types

  @impl true
  def calculate(records, _opts, _context) do
    forms = shape(Content.forms())

    Enum.map(records, fn _record -> forms end)
  end

  defp shape(forms) do
    %Types.RosaryForms{
      forms:
        Enum.map(forms["forms"], fn form ->
          %Types.RosaryFormInfo{
            id: form["id"],
            name: form["name"],
            recorded_as: form["recorded_as"],
            kicker: form["kicker"],
            subtitle: form["subtitle"],
            detail: form["detail"],
            about: form["about"]
          }
        end),
      choices:
        Enum.map(forms["choices"], fn choice ->
          %Types.RosaryChoice{
            id: choice["id"],
            title: choice["title"],
            icon: choice["icon"],
            options:
              Enum.map(choice["options"], fn option ->
                %Types.RosaryChoiceOption{
                  form: option["form"],
                  value: option["value"],
                  name: option["name"],
                  note: option["note"]
                }
              end)
          }
        end),
      offered: Enum.map(forms["offered"], &rule/1),
      rows: Enum.map(forms["rows"], &rule/1),
      row_titles:
        Enum.map(forms["row_titles"], &%Types.RosaryRowTitle{id: &1["id"], title: &1["title"]}),
      holy_audio_value: forms["holy_audio_value"]
    }
  end

  defp rule(rule) do
    %Types.RosaryFormRule{
      form: rule["form"],
      when_aloud: rule["when_aloud"],
      when_silent: rule["when_silent"]
    }
  end
end
