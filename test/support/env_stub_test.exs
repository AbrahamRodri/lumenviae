defmodule LumenViae.Test.EnvStubTest do
  @moduledoc """
  The bug this guards against cost an afternoon: the restore deleted a key
  that had been present carrying nil, ExAws fell back to its default
  credential chain, and an unrelated test exited on a `GenServer.call` to
  `ExAws.Config.AuthCache` while the EC2 instance metadata endpoint timed
  out. It only reproduced on some seeds, and never in the file that caused
  it.
  """
  use ExUnit.Case, async: false

  alias LumenViae.Test.EnvStub

  @app :lumen_viae
  @key :env_stub_test_key

  setup do
    on_exit(fn -> Application.delete_env(@app, @key) end)
    :ok
  end

  describe "snapshot/1" do
    # The whole point. :ex_aws, :access_key_id is present-and-nil under test,
    # and deleting it is not the same as writing the nil back.
    test "a key that was present carrying nil is restored as present carrying nil" do
      Application.put_env(@app, @key, nil)
      restore = EnvStub.snapshot([{@app, @key}])

      Application.put_env(@app, @key, "test-key")
      restore.()

      assert Application.fetch_env(@app, @key) == {:ok, nil}
    end

    test "a key that was never set is deleted again, not written as nil" do
      Application.delete_env(@app, @key)
      restore = EnvStub.snapshot([{@app, @key}])

      Application.put_env(@app, @key, "test-key")
      restore.()

      assert Application.fetch_env(@app, @key) == :error
    end

    test "a key that had a real value gets it back" do
      Application.put_env(@app, @key, "original")
      restore = EnvStub.snapshot([{@app, @key}])

      Application.put_env(@app, @key, "test-key")
      restore.()

      assert Application.fetch_env(@app, @key) == {:ok, "original"}
    end

    test "restores every key it was given" do
      other = :env_stub_test_other_key
      on_exit(fn -> Application.delete_env(@app, other) end)

      Application.put_env(@app, @key, nil)
      Application.delete_env(@app, other)
      restore = EnvStub.snapshot([{@app, @key}, {@app, other}])

      Application.put_env(@app, @key, "a")
      Application.put_env(@app, other, "b")
      restore.()

      assert Application.fetch_env(@app, @key) == {:ok, nil}
      assert Application.fetch_env(@app, other) == :error
    end
  end

  describe "the ExAws credentials this exists to protect" do
    # If :access_key_id is ever missing rather than nil, ExAws substitutes
    # [{:system, ...}, :pod_identity, :instance_role] and the next credential
    # resolution goes to 169.254.169.254 and hangs. Asserting on the resolved
    # config rather than on the raw key catches it however it happened.
    test "resolve to a value, never to the default chain" do
      config = ExAws.Config.new(:s3)

      refute is_list(config.access_key_id),
             "ExAws fell back to its default credential chain: some test deleted " <>
               ":ex_aws, :access_key_id instead of restoring its nil"

      refute is_list(config.secret_access_key)
    end

    test "survive a stub-and-restore cycle" do
      restore =
        EnvStub.snapshot([{:ex_aws, :access_key_id}, {:ex_aws, :secret_access_key}])

      Application.put_env(:ex_aws, :access_key_id, "test-key")
      Application.put_env(:ex_aws, :secret_access_key, "test-secret")
      restore.()

      config = ExAws.Config.new(:s3)

      refute is_list(config.access_key_id)
      refute is_list(config.secret_access_key)
    end
  end
end
