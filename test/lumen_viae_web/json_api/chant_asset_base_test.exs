defmodule LumenViaeWeb.JsonApi.ChantAssetBaseTest do
  @moduledoc """
  The Chant Library's files served from another base by setting alone
  (`:chant_asset_base_url`, `CHANT_ASSET_BASE_URL`): unset, the document is
  the file's, byte for byte; set, every chant URL names the new base and
  the version moves, so the apps fetch the new copy. Not async: the
  setting is the application's.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary.Library

  @path "/chant-library?fields[chant_library]=version,updated_at,groups,chants,feasts,months,occasions"
  @file_base "https://s3.us-east-2.amazonaws.com/lumenviae-images"
  @r2_base "https://media.lumenviae.org"

  setup do
    original = Application.get_env(:lumen_viae, :chant_asset_base_url)

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:lumen_viae, :chant_asset_base_url)
        value -> Application.put_env(:lumen_viae, :chant_asset_base_url, value)
      end
    end)

    Application.delete_env(:lumen_viae, :chant_asset_base_url)
    :ok
  end

  defp document(conn),
    do: conn |> get_v2(@path) |> v2_response(200) |> get_in(["data", "attributes"])

  defp urls(attributes) do
    for chant <- attributes["chants"], file <- [chant["audio"] | chant["score"]], do: file["url"]
  end

  test "unset, the document is the file's: same URLs, same version", %{conn: conn} do
    attributes = document(conn)

    assert Library.chant_asset_base() == @file_base
    assert Enum.all?(urls(attributes), &String.starts_with?(&1, @file_base <> "/chants/"))

    [file] = Enum.filter(Library.files(), &(&1.name == "chant_library.json"))
    assert attributes["version"] == file.version
  end

  test "an empty setting counts as unset", %{conn: conn} do
    unset = document(conn)
    Application.put_env(:lumen_viae, :chant_asset_base_url, "")

    assert document(build_conn()) == unset
  end

  test "set, every chant URL is on the new base and the version moves", %{conn: conn} do
    unset = document(conn)

    # A trailing slash is ignored.
    Application.put_env(:lumen_viae, :chant_asset_base_url, @r2_base <> "/")
    moved = document(build_conn())

    assert Library.chant_asset_base() == @r2_base
    assert length(urls(moved)) == length(urls(unset))
    assert Enum.all?(urls(moved), &String.starts_with?(&1, @r2_base <> "/chants/"))

    # Nothing but the base changed: put the file's base back and it is the
    # file's document again.
    back =
      moved
      |> Map.drop(["version"])
      |> rebase(@r2_base <> "/chants/", @file_base <> "/chants/")

    assert back == Map.drop(unset, ["version"])
    assert moved["updated_at"] == unset["updated_at"]
    assert moved["version"] != unset["version"]

    # The bare request a device polls with says the same version.
    bare = build_conn() |> get_v2("/chant-library") |> v2_response(200)
    assert bare["data"]["attributes"]["version"] == moved["version"]
  end

  defp rebase(map, from, to) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, rebase(value, from, to)} end)

  defp rebase(list, from, to) when is_list(list), do: Enum.map(list, &rebase(&1, from, to))

  defp rebase(string, from, to) when is_binary(string),
    do:
      if(String.starts_with?(string, from),
        do: to <> String.replace_prefix(string, from, ""),
        else: string
      )

  defp rebase(value, _from, _to), do: value
end
