defmodule Mix.Tasks.LumenViae.CopyStorage do
  @shortdoc "Copies a bucket from AWS S3 to Cloudflare R2, never deleting"

  @moduledoc """
  Copies every object under a prefix from the app's S3 bucket to the
  bucket of the same name on Cloudflare R2 (`LumenViae.Storage.Copy`).

      mix lumen_viae.copy_storage --from s3 --to r2 --prefix voices/ --dry-run
      mix lumen_viae.copy_storage --from s3 --to r2 --prefix voices/

  It copies only what R2 is missing or holds with a different size or MD5, keeps
  each object's content type and cache control, and checks every copy's
  size and MD5 after it lands. It never deletes, on either side, so a run
  is safe to repeat and to stop halfway.

  **Dry-run first.** The dry run lists both buckets and prints what a run
  would copy, with counts and bytes, and writes nothing.

  Only Abraham runs this, after R2 is enabled; the plan is
  `reports/rig/cloudflare-plan.md`. Nothing reads from R2 until the
  `S3_HOST` and `S3_REGION` settings point the app at it.

  ## Options

    * `--from s3 --to r2` - the only direction there is; both are required
      so a run says what it does
    * `--bucket` - the source bucket (default: the app's `AWS_S3_BUCKET`,
      `lumenviae-audio`)
    * `--to-bucket` - the R2 bucket (default: the same name)
    * `--prefix` - copy only keys starting with this (default: everything)
    * `--dry-run` - list and count, copy nothing

  ## Environment

  The source side uses the AWS credentials in the environment. Listing a
  bucket needs `s3:ListBucket`, which the app's own upload user and the
  `lumenviae-agent` profile do not have, so a run needs credentials that
  may list the source bucket.

  The R2 side needs `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID` and
  `R2_SECRET_ACCESS_KEY` (an R2 API token with write access to the
  bucket).
  """

  use Mix.Task

  alias LumenViae.Storage.Copy
  alias LumenViae.Storage.Copy.S3Store

  @switches [
    from: :string,
    to: :string,
    bucket: :string,
    to_bucket: :string,
    prefix: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] -> Mix.raise("Invalid options: #{inspect(invalid)}")
      argv != [] -> Mix.raise("Unexpected arguments: #{inspect(argv)}")
      {opts[:from], opts[:to]} != {"s3", "r2"} -> Mix.raise("Say --from s3 --to r2")
      true -> copy(opts)
    end
  end

  defp copy(opts) do
    for app <- [:req, :ex_aws], do: {:ok, _} = Application.ensure_all_started(app)
    Mix.Task.run("app.config")

    bucket = opts[:bucket] || Application.fetch_env!(:lumen_viae, :aws_s3_bucket)
    to_bucket = opts[:to_bucket] || bucket
    prefix = opts[:prefix] || ""
    dry_run = opts[:dry_run] || false

    source = {S3Store, {bucket, []}}
    destination = {S3Store, {to_bucket, r2_config(System.get_env())}}

    Mix.shell().info(
      "#{if dry_run, do: "Dry run: ", else: ""}s3://#{bucket}/#{prefix} -> r2://#{to_bucket}/#{prefix}"
    )

    result = Copy.run(source, destination, prefix: prefix, dry_run: dry_run, on_object: &line/1)

    Mix.shell().info(summary(result, dry_run))
    if result.failed != [], do: Mix.raise("#{length(result.failed)} copies failed the check")
  end

  @doc false
  # The ex_aws overrides for R2: its own host and keys, region `auto`.
  def r2_config(env) do
    account = fetch!(env, "R2_ACCOUNT_ID")

    [
      scheme: "https://",
      host: "#{account}.r2.cloudflarestorage.com",
      region: "auto",
      access_key_id: fetch!(env, "R2_ACCESS_KEY_ID"),
      secret_access_key: fetch!(env, "R2_SECRET_ACCESS_KEY")
    ]
  end

  defp fetch!(env, name) do
    case Map.get(env, name) do
      value when is_binary(value) and value != "" -> value
      _ -> Mix.raise("#{name} is not set")
    end
  end

  defp line({:present, _key, _size}), do: :ok
  defp line({:to_copy, key, size}), do: Mix.shell().info("WOULD #{key} (#{size} bytes)")
  defp line({:copied, key, size}), do: Mix.shell().info("OK    #{key} (#{size} bytes)")
  defp line({{:failed, why}, key, _size}), do: Mix.shell().error("FAIL  #{key}: #{why}")

  @doc false
  def summary(result, true = _dry_run) do
    "#{result.present} already on R2; #{result.to_copy} to copy (#{result.to_copy_bytes} bytes)"
  end

  def summary(result, false) do
    "#{result.present} already on R2; #{result.copied} copied (#{result.copied_bytes} bytes); " <>
      "#{length(result.failed)} failed"
  end
end
