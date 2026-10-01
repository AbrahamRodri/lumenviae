defmodule LumenViae.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LumenViae.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias LumenViae.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import LumenViae.DataCase
    end
  end

  setup tags do
    LumenViae.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(LumenViae.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      interpolate(message, opts)
    end)
  end

  # The same map of messages for an error from an Ash action, read the way
  # an AshPhoenix form reads it, so a test asserts on what the admin would
  # actually be shown.
  #
  #     assert {:error, error} = Rosary.create_author(%{})
  #     assert %{name: ["is required"]} = errors_on(error)
  def errors_on(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.flat_map(fn error ->
      if AshPhoenix.FormData.Error.impl_for(error) do
        error |> AshPhoenix.FormData.Error.to_form_error() |> List.wrap()
      else
        []
      end
    end)
    |> Enum.reduce(%{}, fn {field, message, vars}, acc ->
      Map.update(acc, field, [interpolate(message, vars)], &(&1 ++ [interpolate(message, vars)]))
    end)
  end

  defp interpolate(message, vars) do
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      vars |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
