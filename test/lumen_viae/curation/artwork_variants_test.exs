defmodule LumenViae.Curation.ArtworkVariantsTest do
  @moduledoc """
  The upload and the backfill against `FakeAwsHttpClient`'s remembering
  bucket: nothing here can reach a real one.
  """
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.ArtworkUpload
  alias LumenViae.Curation.ArtworkVariants
  alias LumenViae.Rosary
  alias LumenViae.Test.FakeAwsHttpClient
  alias Vix.Vips.Operation

  setup do
    put_env(:ex_aws, :http_client, FakeAwsHttpClient)
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :fake_aws_test_pid, self())
    FakeAwsHttpClient.store!()

    {:ok, author} =
      Rosary.create_author(%{name: "Variants #{System.unique_integer([:positive])}"},
        actor: admin()
      )

    %{author: author}
  end

  defp jpeg(width, height) do
    {:ok, x} = Operation.xyz(width, height)
    {:ok, band} = Operation.extract_band(x, 0)
    {:ok, band} = Operation.cast(band, :VIPS_FORMAT_UCHAR)
    {:ok, rgb} = Operation.bandjoin([band, band, band])
    {:ok, rgb} = Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    {:ok, binary} = Operation.jpegsave_buffer(rgb, Q: 90)
    binary
  end

  # A painting stored as it was before variants existed: the original in
  # the bucket, the row recording no widths.
  defp stored_painting(author, width, height) do
    key = "authors/#{author.id}/#{System.unique_integer([:positive])}.jpg"
    FakeAwsHttpClient.put_object!(key, %{}, jpeg(width, height))

    {:ok, author} =
      Rosary.update_author_artwork(
        author,
        %{"image_key" => key, "image_width" => width, "image_height" => height},
        actor: admin()
      )

    author
  end

  defp reload(author), do: Rosary.get_author!(author.id, actor: admin())

  defp drain_requests(acc \\ []) do
    receive do
      {:aws_request, method, url, _body} -> drain_requests([{method, url} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  describe "ArtworkUpload.upload/3" do
    test "stores the original untouched, then each variant, and returns their widths" do
      original = jpeg(1700, 1200)

      assert {:ok, fields} = ArtworkUpload.upload(original, :author, 9)

      key = fields["image_key"]
      assert fields["image_variant_widths"] == [480, 960, 1600]
      assert FakeAwsHttpClient.object_body(key) == original

      for width <- [480, 960, 1600] do
        assert <<"RIFF", _::32, "WEBP", _::binary>> =
                 FakeAwsHttpClient.object_body(String.replace(key, ".jpg", "-#{width}.webp"))
      end
    end

    @tag :capture_log
    test "a refused original fails the upload, so no row points at a missing object" do
      put_env(:lumen_viae, :fake_aws_refuse_puts, true)

      assert {:error, _message} = ArtworkUpload.upload(jpeg(1700, 1200), :author, 9)
    end
  end

  describe "the mix task" do
    setup do
      shell = Mix.shell()
      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(shell) end)
    end

    defp said(kind) do
      receive do
        {:mix_shell, ^kind, [text]} -> [text | said(kind)]
      after
        0 -> []
      end
    end

    @tag :capture_log
    test "exits non-zero with a summary when an upload is refused", %{author: author} do
      stored_painting(author, 1300, 1600)
      put_env(:lumen_viae, :fake_aws_refuse_puts, true)

      assert catch_exit(Mix.Tasks.LumenViae.ArtworkVariants.run([])) == {:shutdown, 1}

      assert Enum.any?(said(:info), &(&1 =~ "0 succeeded, 0 with warnings, 1 failed"))
      assert Enum.any?(said(:error), &(&1 =~ "1 painting(s) failed"))
    end

    test "exits normally when every variant was stored", %{author: author} do
      stored_painting(author, 1300, 1600)

      Mix.Tasks.LumenViae.ArtworkVariants.run([])
      assert Enum.any?(said(:info), &(&1 =~ "1 succeeded, 0 with warnings, 0 failed"))
    end
  end

  describe "a photograph tagged with a quarter turn" do
    # Stored 1700x1200, tagged orientation 6: shown 1200 wide and 1700 tall.
    @rotated "test/support/fixtures/orientation_6.jpg"

    test "is uploaded with the size it is shown at, and variants that size" do
      assert {:ok, fields} = ArtworkUpload.upload(File.read!(@rotated), :author, 9)

      assert fields["image_width"] == 1200
      assert fields["image_height"] == 1700
      assert fields["image_variant_widths"] == [480, 960]
    end

    test "recorded sideways before, is corrected once and then left alone", %{author: author} do
      key = "authors/#{author.id}/rotated.jpg"
      FakeAwsHttpClient.put_object!(key, %{}, File.read!(@rotated))

      # As the header-only reading recorded it: the stored geometry.
      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{"image_key" => key, "image_width" => 1700, "image_height" => 1200},
          actor: admin()
        )

      assert [{:ok, message}] = ArtworkVariants.run(authorize?: false)
      assert message =~ "Made 480, 960px variants"

      author = reload(author)
      assert {author.image_width, author.image_height} == {1200, 1700}
      assert author.image_variant_widths == [480, 960]

      assert ArtworkVariants.run(dry_run: true, authorize?: false) == []
      assert ArtworkVariants.run(authorize?: false) == []
    end
  end

  describe "recording artwork" do
    test "a new painting recorded without widths does not keep the old one's", %{
      author: author
    } do
      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{
            "image_key" => "authors/1/a.jpg",
            "image_width" => 2000,
            "image_height" => 2500,
            "image_variant_widths" => [480, 960, 1600]
          },
          actor: admin()
        )

      assert author.image_variant_widths == [480, 960, 1600]

      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{"image_key" => "authors/1/b.jpg", "image_width" => 2000, "image_height" => 2500},
          actor: admin()
        )

      assert author.image_variant_widths == []
    end

    test "a new painting recorded with the same widths as the old one keeps them", %{
      author: author
    } do
      widths = [480, 960, 1600]

      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{
            "image_key" => "authors/1/a.jpg",
            "image_width" => 2000,
            "image_height" => 2500,
            "image_variant_widths" => widths
          },
          actor: admin()
        )

      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{
            "image_key" => "authors/1/b.jpg",
            "image_width" => 2000,
            "image_height" => 2500,
            "image_variant_widths" => widths
          },
          actor: admin()
        )

      assert author.image_key == "authors/1/b.jpg"
      assert author.image_variant_widths == widths
      assert reload(author).image_variant_widths == widths
    end

    test "variants are refused when the painting changed after the record was read", %{
      author: author
    } do
      stale = stored_painting(author, 1300, 1600)

      {:ok, _replaced} =
        Rosary.update_author_artwork(
          stale,
          %{
            "image_key" => "authors/1/replaced.jpg",
            "image_width" => 1300,
            "image_height" => 1600
          },
          actor: admin()
        )

      assert {:error, error} =
               Rosary.record_author_artwork_variants(
                 stale,
                 %{image_variant_widths: [480, 960], for_image_key: stale.image_key},
                 actor: admin()
               )

      assert Rosary.error_summary(error) =~ "image_key"
      assert reload(stale).image_variant_widths == []
    end

    test "variants made from a key the record no longer has are refused", %{author: author} do
      author = stored_painting(author, 1300, 1600)

      assert {:error, error} =
               Rosary.record_author_artwork_variants(
                 author,
                 %{image_variant_widths: [480, 960], for_image_key: "authors/1/replaced.jpg"},
                 actor: admin()
               )

      assert Rosary.error_summary(error) =~ "image_key"
      assert reload(author).image_variant_widths == []
    end
  end

  describe "run/1" do
    test "a dry run lists the paintings that need variants and changes nothing", %{
      author: author
    } do
      author = stored_painting(author, 1300, 1600)
      drain_requests()

      results = ArtworkVariants.run(dry_run: true, authorize?: false)

      assert [{:ok, message}] = results
      assert message =~ "Would make 480, 960px variants of #{author.image_key}"
      assert message =~ "author #{author.id}"

      assert drain_requests() == []
      assert reload(author).image_variant_widths == []
    end

    test "makes and records the missing variants, and a second run has nothing to do", %{
      author: author
    } do
      author = stored_painting(author, 1700, 1200)

      assert [{:ok, message}] = ArtworkVariants.run(authorize?: false)
      assert message =~ "Made 480, 960, 1600px variants"

      assert reload(author).image_variant_widths == [480, 960, 1600]

      for width <- [480, 960, 1600] do
        assert FakeAwsHttpClient.object_body(
                 String.replace(author.image_key, ".jpg", "-#{width}.webp")
               )
      end

      assert ArtworkVariants.run(authorize?: false) == []
    end

    test "leaves the History panel alone", %{author: author} do
      author = stored_painting(author, 1300, 1600)
      before = length(Rosary.list_history(author, actor: admin()))

      ArtworkVariants.run(authorize?: false)

      assert length(Rosary.list_history(author, actor: admin())) == before
    end

    test "a painting whose original is missing is a warning, and stays as it was", %{
      author: author
    } do
      {:ok, author} =
        Rosary.update_author_artwork(
          author,
          %{"image_key" => "authors/1/gone.jpg", "image_width" => 1300, "image_height" => 1600},
          actor: admin()
        )

      assert [{:warning, message}] = ArtworkVariants.run(authorize?: false)
      assert message =~ "No object at authors/1/gone.jpg"
      assert reload(author).image_variant_widths == []
    end

    test "a run whose uploads fail keeps the variants already recorded", %{author: author} do
      author = stored_painting(author, 1300, 1600)

      {:ok, author} =
        Rosary.record_author_artwork_variants(
          author,
          %{image_variant_widths: [480], for_image_key: author.image_key},
          actor: admin()
        )

      put_env(:lumen_viae, :fake_aws_refuse_puts, true)

      assert [{:error, message}] = results = ArtworkVariants.run(authorize?: false)
      assert message =~ "Made only"
      assert reload(author).image_variant_widths == [480]

      assert %{succeeded: 0, warnings: 0, failed: 1, failures: [^message]} =
               ArtworkVariants.summarize(results)
    end

    test "an original too small for any variant is never pending", %{author: author} do
      stored_painting(author, 400, 600)

      assert ArtworkVariants.run(dry_run: true, authorize?: false) == []
    end
  end
end
