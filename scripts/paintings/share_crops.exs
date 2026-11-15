# Makes each painting's link-preview card, `<name>-share.jpg`: a 1.91:1
# crop (the shape Facebook, iMessage, WhatsApp and X show large) of the
# app's full-size painting, centred on the point the website hangs it by,
# and records its size in manifest.json as "share". At most 1200 pixels
# wide, at least 600 (the large card's floor); a painting narrower than
# 1200 keeps its own width rather than being blown up.
#
#     mix run scripts/paintings/share_crops.exs ~/Developer/lumenviae/ios/app/Assets.xcassets
#
# A novena whose own art is not one of these paintings gets its card from
# that art (priv/library/prayer_book.json's `art`, on the public images
# bucket) as `priv/static/images/novenas/<prayer id>-share.jpg`, listed in
# that folder's manifest.json; only art credited Public domain or CC0, since
# a card has no room for an attribution.
#
# Reads the iOS repo and the public bucket only. Run it again after a
# painting is added or replaced; it rewrites every card. See
# docs/MYSTERY_PAINTINGS.md.

alias Vix.Vips.{Image, Operation}

[assets] = System.argv()
dir = Path.expand("priv/static/images/paintings")
manifest_path = Path.join(dir, "manifest.json")
manifest = manifest_path |> File.read!() |> Jason.decode!(objects: :ordered_objects)

ratio = 1200 / 630

# Where the website hangs each painting: the first `{"name", x, y}` the
# pages name it with, else a little above the middle, where faces sit.
focal =
  Path.wildcard("lib/**/*.ex")
  |> Enum.flat_map(fn file ->
    Regex.scan(~r/\{"([a-z0-9_]+)",\s*([0-9.]+),\s*([0-9.]+)\}/, File.read!(file))
  end)
  |> Enum.reduce(%{}, fn [_, name, x, y], acc ->
    Map.put_new(acc, name, {String.to_float(x), String.to_float(y)})
  end)

# Paintings whose subject the first focal point misses at this wide
# shape: checked by eye on the cards.
overrides = %{
  "undoer_of_knots_novena" => {0.5, 0.12},
  "our_lady_of_guadalupe_novena" => {0.5, 0.12}
}

crop = fn name, source, out ->
  {:ok, img} = Image.new_from_file(source)
  {w, h} = {Image.width(img), Image.height(img)}
  {fx, fy} = Map.get(overrides, name) || Map.get(focal, name, {0.5, 0.35})

  {cw, ch} =
    if w / h < ratio, do: {w, round(w / ratio)}, else: {round(h * ratio), h}

  left = (fx * w - cw / 2) |> max(0) |> min(w - cw) |> round()
  top = (fy * h - ch / 2) |> max(0) |> min(h - ch) |> round()
  {:ok, area} = Operation.extract_area(img, left, top, cw, ch)

  tw = cw |> min(1200) |> max(600)
  th = round(tw / ratio)
  {:ok, sized} = Operation.resize(area, tw / cw, vscale: th / ch)

  :ok =
    Image.write_to_file(sized, out <> "[Q=72,strip,optimize_coding]")

  {tw, th}
end

paintings =
  Enum.map(manifest["paintings"], fn painting ->
    name = painting["name"]
    [source] = Path.wildcard(Path.join([assets, "#{name}.imageset", "*.{jpg,jpeg,png}"]))
    {tw, th} = crop.(name, source, Path.join(dir, "#{name}-share.jpg"))
    IO.puts("#{name} #{tw}x#{th}")

    painting
    |> Map.fetch!(:values)
    |> Enum.reject(fn {k, _} -> k == "share" end)
    |> Kernel.++([{"share", [tw, th]}])
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

# The novenas' own art, where it is none of the paintings above.
novena_alts = %{
  "undoer_of_knots_novena" => "Mary, Untier of Knots, by Johann Georg Melchior Schmidtner",
  "our_lady_of_guadalupe_novena" => "Our Lady of Guadalupe, the image on St Juan Diego's tilma",
  "our_mother_of_perpetual_help_novena" => "Our Mother of Perpetual Help, after the icon in Rome"
}

painted = MapSet.new(manifest["paintings"], & &1["name"])
novena_dir = Path.expand("priv/static/images/novenas")
File.mkdir_p!(novena_dir)
tmp = Path.join(System.tmp_dir!(), "share_crops")
File.mkdir_p!(tmp)

novenas =
  "priv/library/prayer_book.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("novenas")
  |> Enum.filter(fn n ->
    credit = get_in(n, ["art", "credit"]) || ""

    not MapSet.member?(painted, n["painting"]) and
      (credit =~ "Public domain" or credit =~ "CC0") and not (credit =~ "CC BY")
  end)
  |> Enum.map(fn n ->
    id = n["prayer_id"]
    source = Path.join(tmp, id <> Path.extname(n["art"]["url"]))
    {_, 0} = System.cmd("curl", ["-sfL", "-o", source, n["art"]["url"]])
    {tw, th} = crop.(id, source, Path.join(novena_dir, "#{id}-share.jpg"))
    IO.puts("#{id} #{tw}x#{th}")
    # Said as the paintings above say theirs: "Title, by Artist".
    alt =
      Map.get(novena_alts, id) || Mix.raise("#{id}: add its card's alt text to novena_alts")

    {id, %{"share" => [tw, th], "alt" => alt}}
  end)
  |> Map.new()

File.write!(
  Path.join(novena_dir, "manifest.json"),
  Jason.encode_to_iodata!(novenas, pretty: true) |> IO.iodata_to_binary() |> Kernel.<>("\n")
)
