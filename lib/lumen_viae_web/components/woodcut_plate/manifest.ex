defmodule LumenViaeWeb.Components.WoodcutPlate.Manifest do
  @moduledoc """
  Reads the woodcut manifest for `LumenViaeWeb.Components.WoodcutPlate`.

  Kept apart from the component because the component calls it while it
  compiles, which a module cannot do with its own functions.
  """

  @formats [{"avif", "image/avif"}, {"webp", "image/webp"}]

  @doc """
  Load the manifest in `dir` and index it by mystery key. An absent manifest
  is an empty index.
  """
  def load(dir, url_root) do
    path = Path.join(dir, "manifest.json")

    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!() |> index(File.ls!(dir), url_root)
    else
      %{}
    end
  end

  @doc """
  Index a decoded manifest by mystery key, with each plate's image URL and
  its alternative formats.

  `files` is the list of file names in the woodcuts directory; it decides
  which WebP and AVIF copies exist (`baptism-dore.webp` at the JPEG's width,
  `baptism-dore-800.webp` at 800 pixels). A plate whose JPEG is not in
  `files` is dropped, so a manifest entry can never render a broken image.
  """
  def index(%{"plates" => plates}, files, url_root) when is_list(plates) do
    files = MapSet.new(files)

    for %{"file" => file, "key" => key} = raw <- plates,
        MapSet.member?(files, file),
        into: %{} do
      {key, build(raw, files, url_root)}
    end
  end

  @doc "A fingerprint of the directory's file names, to notice an added or removed file."
  def listing(dir) do
    case File.ls(dir) do
      {:ok, names} -> names |> Enum.sort() |> :erlang.phash2()
      {:error, _} -> nil
    end
  end

  defp build(raw, files, url_root) do
    %{
      key: raw["key"],
      file: raw["file"],
      src: "#{url_root}/#{raw["file"]}",
      title: raw["title"],
      artist: raw["artist"],
      year: raw["year"],
      series: raw["series"],
      alt: raw["alt"],
      width: raw["width"],
      height: raw["height"],
      source: raw["source"],
      licence: raw["licence"],
      sources: sources(Path.rootname(raw["file"]), raw["width"], files, url_root)
    }
  end

  defp sources(base, full_width, files, url_root) do
    for {ext, type} <- @formats,
        candidates = variants(base, ext, full_width, files),
        candidates != [] do
      srcset =
        candidates
        |> Enum.sort()
        |> Enum.map_join(", ", fn {width, name} -> "#{url_root}/#{name} #{width}w" end)

      %{type: type, srcset: srcset}
    end
  end

  defp variants(base, ext, full_width, files) do
    Enum.flat_map(files, fn name ->
      cond do
        Path.extname(name) != "." <> ext -> []
        name == "#{base}.#{ext}" -> [{full_width, name}]
        true -> sized_variant(name, base)
      end
    end)
  end

  defp sized_variant(name, base) do
    with suffix when suffix != nil <- strip(Path.rootname(name), base <> "-"),
         {width, ""} <- Integer.parse(suffix) do
      [{width, name}]
    else
      _ -> []
    end
  end

  defp strip(string, prefix) do
    if String.starts_with?(string, prefix), do: String.replace_prefix(string, prefix, "")
  end
end
