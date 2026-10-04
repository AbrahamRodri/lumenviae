defmodule LumenViae.Rosary.Types.RosaryLabels do
  @moduledoc """
  The `labels` section: the meditation set labels, how the app names them and the kinds of meditation they describe. The vocabulary is `LumenViae.Rosary.Labels`'s.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :labels, {:array, Types.LabelName},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Every label a set may carry, in the vocabulary's order. A set's labels are stored as `id`."

    field :kinds, {:array, Types.MeditationKind},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The kinds of meditation, for the page that explains them."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_labels
end
