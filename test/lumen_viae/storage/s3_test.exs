defmodule LumenViae.Storage.S3Test do
  @moduledoc """
  Covers `public_url/1` only. It is the one function here that signs nothing
  and calls nothing, so it can be checked exactly; everything else in the
  module is a round trip to AWS.
  """
  use ExUnit.Case, async: false

  alias LumenViae.Storage.S3

  setup do
    original = Application.get_env(:lumen_viae, :public_asset_base_url)

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:lumen_viae, :public_asset_base_url)
        value -> Application.put_env(:lumen_viae, :public_asset_base_url, value)
      end
    end)

    Application.delete_env(:lumen_viae, :public_asset_base_url)
    :ok
  end

  describe "public_url/1" do
    test "builds an unsigned URL in the public bucket" do
      url = S3.public_url("sets/27/8f21c4d9e0b3a7f6.jpg")

      assert url ==
               "https://s3.us-east-2.amazonaws.com/lumenviae-images/sets/27/8f21c4d9e0b3a7f6.jpg"
    end

    test "signs nothing and expires never" do
      url = S3.public_url("sets/27/8f21c4d9e0b3a7f6.jpg")

      refute url =~ "X-Amz-Signature"
      refute url =~ "X-Amz-Expires"
      refute url =~ "?"
    end

    # The presigner addresses buckets path-style, because the configured
    # ex_aws host carries no %{bucket} placeholder. If these two ever
    # disagree, one of them is pointing at a bucket that does not exist.
    test "addresses the bucket the same way the presigner does" do
      # Signing is local arithmetic, so a throwaway key pair is enough to see
      # which URL shape the presigner produces.
      with_fake_credentials(fn ->
        {:ok, presigned} = S3.generate_presigned_url("meditation.mp3")
        [presigned_origin, _query] = String.split(presigned, "?", parts: 2)

        public = S3.public_url("sets/27/painting.jpg")

        assert String.starts_with?(presigned_origin, "https://s3.us-east-2.amazonaws.com/")
        assert String.starts_with?(public, "https://s3.us-east-2.amazonaws.com/")
      end)
    end

    defp with_fake_credentials(fun) do
      previous = Application.get_all_env(:ex_aws)
      Application.put_env(:ex_aws, :access_key_id, "AKIATESTTESTTESTTEST")
      Application.put_env(:ex_aws, :secret_access_key, "test-secret-not-a-real-key")

      try do
        fun.()
      after
        Application.put_env(:ex_aws, :access_key_id, previous[:access_key_id])
        Application.put_env(:ex_aws, :secret_access_key, previous[:secret_access_key])
      end
    end

    test "uses PUBLIC_ASSET_BASE_URL when one is configured, so a CDN needs no data change" do
      Application.put_env(:lumen_viae, :public_asset_base_url, "https://assets.lumenviae.com")

      assert S3.public_url("sets/27/painting.jpg") ==
               "https://assets.lumenviae.com/sets/27/painting.jpg"
    end

    test "does not double the slash when the configured base URL ends in one" do
      Application.put_env(:lumen_viae, :public_asset_base_url, "https://assets.lumenviae.com/")

      assert S3.public_url("sets/27/painting.jpg") ==
               "https://assets.lumenviae.com/sets/27/painting.jpg"
    end

    test "escapes a key that is not URL-safe, without escaping its separators" do
      assert S3.public_url("sets/27/a painting.jpg") =~ "/sets/27/a%20painting.jpg"
    end

    test "returns nil for a set with no artwork" do
      assert S3.public_url(nil) == nil
      assert S3.public_url("") == nil
    end
  end
end
