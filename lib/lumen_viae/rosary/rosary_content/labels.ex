defmodule LumenViae.Rosary.RosaryContent.Labels do
  @moduledoc """
  The `labels` section of `LumenViae.Rosary.RosaryContent`: the meditation
  set labels, how the app names them and the kinds of meditation they
  describe, shaped as `LumenViae.Rosary.Types.RosaryLabels`.

  The vocabulary and its words are `LumenViae.Rosary.Labels`'s, so the
  section is code, not a file in `priv/rosary_content/`, and is dated here:
  `@updated_at` is when the vocabulary, a display name or a kind last
  changed, and `test/lumen_viae/rosary/rosary_content/labels_test.exs` pins
  the section's version against it, as the content files' histories are
  pinned. Change one: bump `@updated_at` and add the version the test
  prints. The section's value is folded into the document's version through
  `LumenViae.Rosary.RosaryContent.Current.stamp/2`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Labels
  alias LumenViae.Rosary.Types

  @updated_at ~U[2026-10-04 02:40:00Z]

  @impl true
  def calculate(records, _opts, _context) do
    labels = shape(section())

    Enum.map(records, fn _record -> labels end)
  end

  @doc """
  The section as served, string keys throughout: every label in the
  vocabulary's order with what the app calls it, and the kinds.
  """
  @spec section() :: map
  def section do
    %{
      "labels" =>
        for label <- Labels.vocabulary() do
          %{"id" => label, "name" => Labels.display_name(label)}
        end,
      "kinds" => Labels.kinds()
    }
  end

  @doc "A fingerprint of `section/0`, pinned in the section's test."
  @spec version() :: String.t()
  def version, do: Content.version(section())

  @doc "When the vocabulary, a name or a kind last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  defp shape(%{"labels" => labels, "kinds" => kinds}) do
    %Types.RosaryLabels{
      labels: Enum.map(labels, &%Types.LabelName{id: &1["id"], name: &1["name"]}),
      kinds:
        Enum.map(kinds, fn kind ->
          %Types.MeditationKind{
            label: kind["label"],
            icon: kind["icon"],
            title: kind["title"],
            description: kind["description"]
          }
        end)
    }
  end
end
