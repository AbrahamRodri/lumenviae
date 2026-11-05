defmodule LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks do
  @moduledoc """
  The visitor's "Your Rosary Today" choices, and the prayer-page links they
  are carried in.

  The only choice left is the narration voice, a plain map:

    * `voice` - a narration voice's slug

  Every link names only what differs from the prayer page's defaults
  (form=meditation, the default voice), in the order `form`, `voice`:

      /meditation-sets/:set_id/pray?voice=male
      /mysteries/:category/pray?form=scriptural
      /mysteries/:category/pray?form=holy&voice=male

  A browser's older saved choices carry `aloud` and `count` too; they are
  ignored, since the prayer page says every prayer aloud on its own.
  """

  alias LumenViae.Rosary.Voices

  @type form :: :meditation | :scriptural | :holy
  @type choices :: %{voice: String.t()}

  @doc "The choices before the visitor has made any."
  @spec defaults() :: choices
  def defaults, do: %{voice: Voices.default().slug}

  @doc """
  Folds what a form or the browser's saved copy says into `choices`,
  keeping the current value of anything missing or not recognised.
  """
  @spec merge(choices, map) :: choices
  def merge(choices, params) when is_map(params) do
    %{voice: if(params["voice"] in Voices.slugs(), do: params["voice"], else: choices.voice)}
  end

  def merge(choices, _params), do: choices

  @doc "The choices as the browser keeps them, string keys and values."
  @spec to_storage(choices) :: map
  def to_storage(choices) do
    %{"voice" => choices.voice}
  end

  @doc "Where a meditation set is prayed with these choices."
  @spec set_path(integer | String.t(), choices) :: String.t()
  def set_path(set_id, choices), do: path("/meditation-sets/#{set_id}/pray", :meditation, choices)

  @doc "Where a category is prayed without a set, in the Scriptural Rosary or with no meditation."
  @spec way_path(String.t(), :scriptural | :holy, choices) :: String.t()
  def way_path(category, form, choices) when form in [:scriptural, :holy] do
    path("/mysteries/#{category}/pray", form, choices)
  end

  defp path(base, form, choices) do
    case query(form, choices) do
      [] -> base
      params -> base <> "?" <> URI.encode_query(params)
    end
  end

  defp query(form, choices), do: form_param(form) ++ voice_param(choices)

  defp form_param(:meditation), do: []
  defp form_param(form), do: [form: Atom.to_string(form)]

  defp voice_param(%{voice: voice}) do
    if voice == Voices.default().slug, do: [], else: [voice: voice]
  end

  @doc """
  The voice in a few words for a row ("Male voice"), or nil while there is
  no choice of voice.
  """
  @spec summary(choices) :: String.t() | nil
  def summary(%{voice: slug}) do
    case Voices.list() do
      [_only] -> nil
      _voices -> voice_name(slug) <> " voice"
    end
  end

  @doc "A voice's name, from its slug."
  @spec voice_name(String.t()) :: String.t()
  def voice_name(slug) do
    case Voices.get(slug) do
      nil -> Voices.default().name
      voice -> voice.name
    end
  end
end
