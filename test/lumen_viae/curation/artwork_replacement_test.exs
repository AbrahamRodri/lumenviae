defmodule LumenViae.Curation.ArtworkReplacementTest do
  @moduledoc """
  Replacing a set's painting against `FakeAwsHttpClient`'s remembering
  bucket: nothing here can reach a real one.
  """
  use LumenViae.DataCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 3]

  alias LumenViae.Curation.ArtworkReplacement
  alias LumenViae.Rosary
  alias LumenViae.Test.FakeAwsHttpClient
  alias Vix.Vips.Operation

  setup do
    put_env(:ex_aws, :http_client, FakeAwsHttpClient)
    put_env(:ex_aws, :access_key_id, "test-key")
    put_env(:ex_aws, :secret_access_key, "test-secret")
    put_env(:lumen_viae, :fake_aws_test_pid, self())
    FakeAwsHttpClient.store!()
    :ok
  end

  defp jpeg(width, height, shade \\ 0) do
    {:ok, x} = Operation.xyz(width, height)
    {:ok, band} = Operation.extract_band(x, 0)
    {:ok, band} = Operation.linear(band, [1.0], [shade / 1])
    {:ok, band} = Operation.cast(band, :VIPS_FORMAT_UCHAR)
    {:ok, rgb} = Operation.bandjoin([band, band, band])
    {:ok, rgb} = Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    {:ok, binary} = Operation.jpegsave_buffer(rgb, Q: 90)
    binary
  end

  @published %{
    "image_alt" => "A portrait.",
    "image_license" => "public_domain",
    "image_focal_x" => 0.3,
    "image_focal_y" => 0.1
  }

  defp painted(write, record, scope) do
    key = "#{scope}/#{record.id}/old#{System.unique_integer([:positive])}.jpg"
    FakeAwsHttpClient.put_object!(key, %{}, jpeg(1200, 1500))

    params =
      Map.merge(@published, %{
        "image_key" => key,
        "image_width" => 1200,
        "image_height" => 1500,
        "image_variant_widths" => [480, 960]
      })

    {:ok, record} = write.(record, params, actor: admin())
    record
  end

  defp create_set(attrs \\ %{}) do
    {:ok, set} =
      Rosary.create_meditation_set(
        Map.merge(
          %{name: "Replace #{System.unique_integer([:positive])}", category: "joyful"},
          attrs
        ),
        actor: admin()
      )

    set
  end

  defp painted_set, do: painted(&Rosary.update_meditation_set_artwork/3, create_set(), "sets")

  defp author_sets do
    {:ok, author} =
      Rosary.create_author(%{name: "Replace #{System.unique_integer([:positive])}"},
        actor: admin()
      )

    author = painted(&Rosary.update_author_artwork/3, author, "authors")
    sets = for _ <- 1..2, do: create_set(%{author_id: author.id})
    {author, sets}
  end

  defp reload_set(set), do: Rosary.get_meditation_set!(set.id, actor: admin())
  defp reload_author(author), do: Rosary.get_author!(author.id, actor: admin())

  test "a set's own painting gets a new key, new variants, and keeps its focal point" do
    set = painted_set()
    new = jpeg(1700, 2100, 40)

    assert [{:ok, "Replaced set " <> _ = message}] =
             ArtworkReplacement.run([set.id], new, actor: admin())

    after_set = reload_set(set)
    refute after_set.image_key == set.image_key
    assert after_set.image_key =~ ~r"^sets/#{set.id}/[0-9a-f]{16}\.jpg$"
    assert {after_set.image_width, after_set.image_height} == {1700, 2100}
    assert after_set.image_variant_widths == [480, 960, 1600]
    assert {after_set.image_focal_x, after_set.image_focal_y} == {0.3, 0.1}
    assert after_set.image_alt == "A portrait."

    assert FakeAwsHttpClient.object_body(after_set.image_key) == new
    # The old original stays for any client still holding its URL.
    assert is_binary(FakeAwsHttpClient.object_body(set.image_key))
    assert message =~ Rosary.artwork_url(set)
    assert message =~ Rosary.artwork_url(after_set)
  end

  test "sets that show their author's portrait replace the portrait once" do
    {author, [one, two]} = author_sets()

    assert [{:ok, "Replaced author " <> _}] =
             ArtworkReplacement.run([one.id, two.id], jpeg(1700, 2100, 40), actor: admin())

    after_author = reload_author(author)
    refute after_author.image_key == author.image_key
    assert after_author.image_key =~ ~r"^authors/#{author.id}/"
    assert after_author.image_variant_widths == [480, 960, 1600]
    # The sets themselves still carry no painting of their own.
    assert reload_set(one).image_key == nil
  end

  test "a dry run checks the file and changes nothing" do
    set = painted_set()

    assert [{:ok, "Would replace set " <> _}] =
             ArtworkReplacement.run([set.id], jpeg(1700, 2100, 40), dry_run: true, actor: admin())

    assert reload_set(set).image_key == set.image_key
    refute_received {:aws_request, :put, _url, _body}
  end

  test "focal and attribution options are written with the new painting" do
    set = painted_set()

    assert [{:ok, _}] =
             ArtworkReplacement.run([set.id], jpeg(1700, 2100, 40),
               focal: {0.5, 0.25},
               attribution: [source_url: "https://archive.org/details/x", artist: "Joseph Brown"],
               actor: admin()
             )

    after_set = reload_set(set)
    assert {after_set.image_focal_x, after_set.image_focal_y} == {0.5, 0.25}
    assert after_set.image_source_url == "https://archive.org/details/x"
    assert after_set.image_artist == "Joseph Brown"
  end

  test "replacing again with the old original points the record back at its old key" do
    set = painted_set()
    old = FakeAwsHttpClient.object_body(set.image_key)

    # The old key in this test is not a content hash, so first replace
    # with a new file, then roll back to that file's own key.
    new = jpeg(1700, 2100, 40)
    [{:ok, _}] = ArtworkReplacement.run([set.id], new, actor: admin())
    first = reload_set(set)
    [{:ok, _}] = ArtworkReplacement.run([set.id], jpeg(1700, 2100, 80), actor: admin())

    assert [{:ok, _}] = ArtworkReplacement.run([set.id], new, actor: admin())
    assert reload_set(set).image_key == first.image_key
    assert is_binary(old)
  end

  test "running it twice with the same file does nothing the second time" do
    set = painted_set()
    new = jpeg(1700, 2100, 40)
    [{:ok, _}] = ArtworkReplacement.run([set.id], new, actor: admin())

    assert [{:ok, message}] = ArtworkReplacement.run([set.id], new, actor: admin())
    assert message =~ "already shows this painting"
  end

  test "refuses a file the console would refuse, and says which record" do
    set = painted_set()

    assert [{:error, "set " <> _ = message}] =
             ArtworkReplacement.run([set.id], jpeg(800, 1000), actor: admin())

    assert message =~ "shortest side"
    assert reload_set(set).image_key == set.image_key
  end

  test "reports a set with no painting and an unknown set" do
    set = create_set()

    assert [{:error, no_painting}, {:error, missing}] =
             ArtworkReplacement.run([set.id, 999_999_999], jpeg(1600, 2000), actor: admin())

    assert no_painting =~ "shows no painting"
    assert missing =~ "No set 999999999"
  end

  test "refuses a focal point outside the picture before uploading anything" do
    set = painted_set()

    assert [{:error, message}] =
             ArtworkReplacement.run([set.id], jpeg(1600, 2000), focal: {1.5, 0}, actor: admin())

    assert message =~ "focal"
    refute_received {:aws_request, :put, _url, _body}
  end
end
