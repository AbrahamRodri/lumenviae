defmodule LumenViae.Rosary.Completion.SetIsVisible do
  @moduledoc """
  Requires the set being completed to be one the public can see.

  A set hidden by an archived meditation answers exactly as a set that was
  never there, so a client cannot use the write to learn that a hidden set
  exists.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias LumenViae.Rosary.MeditationSet

  @impl true
  def validate(changeset, _opts, _context) do
    set_id = Ash.Changeset.get_attribute(changeset, :meditation_set_id)

    visible? =
      is_integer(set_id) and
        MeditationSet
        |> Ash.Query.for_read(:visible)
        |> Ash.Query.filter(id == ^set_id)
        |> Ash.exists?()

    if visible? do
      :ok
    else
      {:error, field: :meditation_set_id, message: "does not exist"}
    end
  end
end
