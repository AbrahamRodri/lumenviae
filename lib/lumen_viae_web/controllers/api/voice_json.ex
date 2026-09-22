defmodule LumenViaeWeb.API.VoiceJSON do
  @doc """
  Renders the list of narration voices, default first.
  """
  def index(%{voices: voices}) do
    %{data: Enum.map(voices, &data/1)}
  end

  @doc """
  The canonical voice shape, shared with every narration that names its
  voice. `slug` is the identifier a client stores and sends back
  (`?voice=female`); `name` and `description` are for the picker.
  """
  def data(voice) do
    %{
      slug: voice.slug,
      name: voice.name,
      description: voice.description,
      default: voice.default
    }
  end
end
