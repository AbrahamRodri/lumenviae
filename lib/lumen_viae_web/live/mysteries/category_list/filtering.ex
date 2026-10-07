defmodule LumenViaeWeb.Live.Mysteries.CategoryList.Filtering do
  @moduledoc """
  Narrows a category's already-loaded sets to the shelf's filters: the
  kinds of meditation chosen (a set must carry every one, as in the app)
  and, when asked, only the narrated sets. Presentation only; it never
  queries.

  The filters live in the URL, `?kinds=Saints,Considerations&narrated=true`,
  so a filtered shelf can be shared and survives a reload.
  """

  alias LumenViae.Rosary.Labels

  @type filters :: %{kinds: [String.t()], narrated: boolean}

  @doc "Reads the filters from the query string, ignoring anything unknown."
  @spec from_params(map) :: filters
  def from_params(params) do
    kinds =
      params
      |> Map.get("kinds", "")
      |> to_string()
      |> String.split(",", trim: true)
      |> Enum.filter(&(&1 in Labels.vocabulary()))
      |> Enum.uniq()

    %{kinds: kinds, narrated: params["narrated"] == "true"}
  end

  @doc "The query string for a set of filters, without its defaults."
  @spec to_params(filters) :: keyword
  def to_params(%{kinds: kinds, narrated: narrated}) do
    kinds_param = if kinds == [], do: [], else: [kinds: Enum.join(kinds, ",")]
    narrated_param = if narrated, do: [narrated: "true"], else: []
    kinds_param ++ narrated_param
  end

  @doc "Whether any filter is narrowing the shelf."
  @spec active?(filters) :: boolean
  def active?(%{kinds: kinds, narrated: narrated}), do: kinds != [] or narrated

  @doc "Adds the kind when it is off, removes it when it is on."
  @spec toggle_kind(filters, String.t()) :: filters
  def toggle_kind(filters, kind) do
    cond do
      kind in filters.kinds -> %{filters | kinds: List.delete(filters.kinds, kind)}
      kind in Labels.vocabulary() -> %{filters | kinds: filters.kinds ++ [kind]}
      true -> filters
    end
  end

  @doc """
  The kinds worth offering for these sets: the vocabulary's labels that at
  least one of them carries, in the vocabulary's order.
  """
  @spec kinds_offered([map]) :: [String.t()]
  def kinds_offered(sets) do
    carried = sets |> Enum.flat_map(&(&1.labels || [])) |> MapSet.new()
    Enum.filter(Labels.vocabulary(), &MapSet.member?(carried, &1))
  end

  @doc "The sets that pass every filter."
  @spec apply_filters([map], filters) :: [map]
  def apply_filters(sets, %{kinds: kinds, narrated: narrated}) do
    Enum.filter(sets, fn set ->
      Enum.all?(kinds, &(&1 in (set.labels || []))) and (not narrated or narrated?(set))
    end)
  end

  @doc "Whether any of the set's meditations has narration."
  @spec narrated?(map) :: boolean
  def narrated?(set), do: Enum.any?(set.meditations, & &1.audio_url)
end
