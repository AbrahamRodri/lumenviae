defmodule LumenViae.Rosary.MeditationSet.ManagedLabels do
  @moduledoc """
  Holds a set's labels to `LumenViae.Rosary.Labels`: every label comes from
  the managed vocabulary, and a set carries no more than the vocabulary's
  maximum.

  Only labels being written are checked, so a set whose labels predate a
  change to the vocabulary can still have its other fields edited.
  """
  use Ash.Resource.Validation

  alias LumenViae.Rosary.Labels

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :labels) do
      {:ok, labels} when is_list(labels) -> check(labels)
      _not_changing -> :ok
    end
  end

  defp check(labels) do
    cond do
      labels -- Labels.vocabulary() != [] ->
        {:error, field: :labels, message: "contains a label outside the managed vocabulary"}

      length(labels) > Labels.max_per_set() ->
        {:error, field: :labels, message: "cannot have more than #{Labels.max_per_set()} labels"}

      true ->
        :ok
    end
  end
end
