defmodule LumenViae.Accounts.ConsoleAdminTest do
  @moduledoc """
  Managing admins from the console: adding one, replacing another's
  password, changing your own. Each needs the acting admin's own password,
  so a stolen session cookie alone cannot plant an admin or lock one out.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Accounts
  alias LumenViae.Accounts.Admin

  defp signs_in?(email, password) do
    strategy = AshAuthentication.Info.strategy!(Admin, :password)

    match?(
      {:ok, _admin},
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: to_string(email),
        password: password
      })
    )
  end

  defp email, do: "new#{System.unique_integer([:positive])}@lumenviae.test"

  defp error_on?(%{errors: errors}, field), do: Enum.any?(errors, &(Map.get(&1, :field) == field))

  describe "adding an admin" do
    test "with the acting admin's own password, gives a generated password that signs in" do
      actor = admin_fixture()
      email = email()

      assert {:ok, admin, password} = Accounts.add_admin(email, password(), actor: actor)
      assert to_string(admin.email) == email
      assert signs_in?(email, password)
    end

    test "is refused without the acting admin's own password" do
      actor = admin_fixture()
      email = email()

      assert {:error, error} = Accounts.add_admin(email, "a guess at it", actor: actor)
      assert error_on?(error, :current_password)
      refute signs_in?(email, "anything")
    end

    test "is refused to anyone but an admin, even with authorization off" do
      email = email()

      assert {:error, _} = Accounts.add_admin(email, password(), actor: nil)

      # With no admin acting there is no password to confirm, so even a
      # caller that switches authorization off is refused.
      assert {:error, error} = Accounts.add_admin(email, password(), authorize?: false)
      assert error_on?(error, :current_password)
      refute signs_in?(email, "anything")
    end
  end

  describe "replacing another admin's password" do
    test "gives them a generated one and the old one stops working" do
      actor = admin_fixture()
      other = admin_fixture()

      assert {:ok, _other, new_password} =
               Accounts.reset_admin_password(other, password(), actor: actor)

      assert signs_in?(other.email, new_password)
      refute signs_in?(other.email, password())
    end

    test "is refused for your own account, which has its own form" do
      actor = admin_fixture()

      assert {:error, _} = Accounts.reset_admin_password(actor, password(), actor: actor)
      assert signs_in?(actor.email, password())
    end
  end

  describe "changing your own password" do
    test "needs the current one and the new one twice" do
      actor = admin_fixture()
      new = "a new password of some length"

      assert {:error, error} =
               Accounts.change_own_password(actor, new, "not the same", password(), actor: actor)

      assert error_on?(error, :password_confirmation)

      assert {:error, error} =
               Accounts.change_own_password(actor, new, new, "wrong", actor: actor)

      assert error_on?(error, :current_password)

      assert {:ok, _} = Accounts.change_own_password(actor, new, new, password(), actor: actor)
      assert signs_in?(actor.email, new)
    end

    test "is refused for another admin's account" do
      actor = admin_fixture()
      other = admin_fixture()
      new = "a new password of some length"

      assert {:error, _} = Accounts.change_own_password(other, new, new, password(), actor: actor)
      assert signs_in?(other.email, password())
    end
  end

  test "ten tries at the password in a window, and then not even the right one works" do
    actor = admin_fixture()

    for _ <- 1..10 do
      assert {:error, _} = Accounts.add_admin(email(), "a guess", actor: actor)
    end

    assert {:error, error} = Accounts.add_admin(email(), password(), actor: actor)
    assert LumenViae.Limits.exceeded(error)
  end
end
