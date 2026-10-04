defmodule LumenViae.Accounts.Admin.ActorIs do
  @moduledoc """
  Whether the admin being changed is the one acting: `self?: true` requires
  it (changing your own password), `self?: false` forbids it (resetting
  someone else's, which would generate you a password you did not choose).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, opts, context) do
    acting_on_self? = match?(%{id: id} when id == changeset.data.id, context.actor)

    cond do
      opts[:self?] and not acting_on_self? ->
        {:error, message: "can only be changed by its own admin"}

      not opts[:self?] and acting_on_self? ->
        {:error, message: "is yours: change it under Your password instead"}

      true ->
        :ok
    end
  end
end
