# Makes each painting's thumbnail, `<name>-240.webp`: the app's full-size
# painting at 240 pixels wide (or its own width, when narrower), for the
# small arches and cards (34 to 160 CSS pixels) that list a painting
# beside a prayer or a chant. Without it a phone fetches the 480 copy for
# a 56 pixel thumb. Records the size in manifest.json as "thumb".
#
#     mix run scripts/paintings/thumbs.exs ~/Developer/lumenviae/ios/app/Assets.xcassets
#
# Reads the iOS repo only. Run it again after a painting is added or
# replaced; it rewrites every thumbnail. See docs/MYSTERY_PAINTINGS.md.

alias Vix.Vips.{Image, Operation}

[assets] = System.argv()
dir = Path.expand("priv/static/images/paintings")
manifest_path = Path.join(dir, "manifest.json")
manifest = manifest_path |> File.read!() |> Jason.decode!(objects: :ordered_objects)

paintings =
  Enum.map(manifest["paintings"], fn painting ->
    name = painting["name"]
    [source] = Path.wildcard(Path.join([assets, "#{name}.imageset", "*.{jpg,jpeg,png}"]))
    {:ok, img} = Image.new_from_file(source)
    w = Image.width(img)
    {:ok, sized} = if w > 240, do: Operation.resize(img, 240 / w), else: {:ok, img}
    out = Path.join(dir, "#{name}-240.webp")
    :ok = Image.write_to_file(sized, out <> "[Q=75,strip,effort=6]")
    {tw, th} = {Image.width(sized), Image.height(sized)}
    IO.puts("#{name} #{tw}x#{th} #{File.stat!(out).size}")

    values = Map.fetch!(painting, :values)
    {before, rest} = Enum.split_while(values, fn {k, _} -> k != "preview" end)

    (Enum.reject(before, fn {k, _} -> k == "thumb" end) ++
       [{"thumb", [tw, th]}] ++ Enum.reject(rest, fn {k, _} -> k == "thumb" end))
    |> Jason.OrderedObject.new()
  end)

manifest =
  manifest
  |> Map.fetch!(:values)
  |> Enum.map(fn
    {"paintings", _} -> {"paintings", paintings}
    pair -> pair
  end)
  |> Jason.OrderedObject.new()

File.write!(
  manifest_path,
  Jason.encode_to_iodata!(manifest, pretty: true) |> IO.iodata_to_binary() |> Kernel.<>("\n")
)
