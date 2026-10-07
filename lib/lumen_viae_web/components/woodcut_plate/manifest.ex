defmodule LumenViaeWeb.Components.WoodcutPlate.Manifest do
  @moduledoc """
  Reads the woodcut manifest for `LumenViaeWeb.Components.WoodcutPlate`.

  Kept apart from the component because the component calls it while it
  compiles, which a module cannot do with its own functions.
  """

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
  its WebP variants.

  A plate's `"webp"` is a map of pixel width to file name, such as
  `{"640": "baptism-dore-640.webp", "1200": "baptism-dore-1200.webp"}`,
  listing only the variants that exist. `files` is the list of file names in
  the woodcuts directory: a plate whose JPEG is not in it is dropped, and so
  is a WebP variant, so a manifest entry can never render a broken image.
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
      sources: sources(raw, files, url_root)
    }
  end

  defp sources(raw, files, url_root) do
    variants =
      for {width, name} <- raw["webp"] || %{},
          MapSet.member?(files, name),
          do: {String.to_integer(width), name}

    if variants == [] do
      []
    else
      srcset =
        variants
        |> Enum.sort()
        |> Enum.map_join(", ", fn {width, name} -> "#{url_root}/#{name} #{width}w" end)

      [%{type: "image/webp", srcset: srcset}]
    end
  end
end
