defmodule LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks do
  @moduledoc """
  The visitor's "Your Rosary Today" choices, and the prayer-page links they
  are carried in.

  The choices are a plain map:

    * `aloud` - `false` for "Meditation only" (the voice reads the
      meditation and the visitor says the prayers), `true` for the Whole
      Rosary said aloud
    * `count` - `"beads"` on the visitor's own rosary, `"screen"` on the
      screen. It only holds while `aloud` is false: with the Whole Rosary
      the voice moves the beads on the screen itself
    * `voice` - a narration voice's slug

  Every link names only what differs from the prayer page's defaults
  (form=meditation, count=beads, aloud off, the default voice), in the
  order `form`, `count`, `aloud`, `voice`:

      /meditation-sets/:set_id/pray?count=screen&voice=male
      /mysteries/:category/pray?form=scriptural&aloud=true
  """

  alias LumenViae.Rosary.Voices

  @counts ~w(beads screen)

  @type form :: :meditation | :scriptural | :holy
  @type choices :: %{aloud: boolean, count: String.t(), voice: String.t()}

  @doc "The choices before the visitor has made any."
  @spec defaults() :: choices
  def defaults, do: %{aloud: false, count: "beads", voice: Voices.default().slug}

  @doc """
  Folds what a form or the browser's saved copy says into `choices`,
  keeping the current value of anything missing or not recognised.
  """
  @spec merge(choices, map) :: choices
  def merge(choices, params) when is_map(params) do
    %{
      aloud: parse_aloud(params["aloud"], choices.aloud),
      count: if(params["count"] in @counts, do: params["count"], else: choices.count),
      voice: if(params["voice"] in Voices.slugs(), do: params["voice"], else: choices.voice)
    }
  end

  def merge(choices, _params), do: choices

  defp parse_aloud(value, _current) when value in [true, "true"], do: true
  defp parse_aloud(value, _current) when value in [false, "false"], do: false
  defp parse_aloud(_value, current), do: current

  @doc "The choices as the browser keeps them, string keys and values."
  @spec to_storage(choices) :: map
  def to_storage(choices) do
    %{"aloud" => to_string(choices.aloud), "count" => choices.count, "voice" => choices.voice}
  end

  @doc "Where a meditation set is prayed with these choices."
  @spec set_path(integer | String.t(), choices) :: String.t()
  def set_path(set_id, choices), do: path("/meditation-sets/#{set_id}/pray", :meditation, choices)

  @doc "Where a category is prayed without a set, in the Scriptural or the said-aloud form."
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

  defp query(form, choices) do
    form_param(form) ++
      count_param(form, choices) ++ aloud_param(form, choices) ++ voice_param(form, choices)
  end

  defp form_param(:meditation), do: []
  defp form_param(form), do: [form: Atom.to_string(form)]

  # The Rosary Said Aloud is always aloud, its beads always on the screen.
  defp count_param(:holy, _choices), do: []
  defp count_param(_form, %{aloud: false, count: "screen"}), do: [count: "screen"]
  defp count_param(_form, _choices), do: []

  defp aloud_param(:holy, _choices), do: []
  defp aloud_param(_form, %{aloud: true}), do: [aloud: "true"]
  defp aloud_param(_form, _choices), do: []

  # The Scriptural Rosary read in silence has no voice to choose.
  defp voice_param(:scriptural, %{aloud: false}), do: []

  defp voice_param(_form, %{voice: voice}) do
    if voice == Voices.default().slug, do: [], else: [voice: voice]
  end

  @doc """
  How a form will be prayed with these choices, in a few words for its
  row: "Read in silence · On my rosary".
  """
  @spec summary(form, choices) :: String.t()
  def summary(:holy, choices), do: Enum.join(["Every prayer aloud" | voice_words(choices)], " · ")

  def summary(form, %{aloud: true} = choices) do
    Enum.join([audio_name(form, true) | voice_words(choices)], " · ")
  end

  def summary(form, %{aloud: false, count: count}) do
    audio_name(form, false) <> " · " <> count_name(count)
  end

  @doc "What the Audio choice's option is called in a form."
  @spec audio_name(form, boolean) :: String.t()
  def audio_name(_form, true), do: "Whole Rosary aloud"
  def audio_name(:scriptural, false), do: "Read in silence"
  def audio_name(_form, false), do: "Meditation only"

  @doc "What a Counting option is called."
  @spec count_name(String.t()) :: String.t()
  def count_name("screen"), do: "On the screen"
  def count_name(_beads), do: "On my rosary"

  defp voice_words(%{voice: slug}) do
    case Voices.list() do
      [_only] -> []
      _voices -> [voice_name(slug) <> " voice"]
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
