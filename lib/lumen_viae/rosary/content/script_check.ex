defmodule LumenViae.Rosary.Content.ScriptCheck do
  @moduledoc """
  Everything `priv/rosary_content/script.json` must hold for every Rosary
  to expand and every field of the content document to be served.
  `LumenViae.Rosary.Content` runs it when it compiles and refuses to
  compile on any error, so a malformed file fails the build, never a
  request: a missing label would otherwise fail the whole
  `GET /api/v2/rosary-content` document, prayers and all, and a missing
  Hail Mary count the website's "Pray aloud".

  `errors/3` never raises on a malformed shape; it describes it.
  """

  @kinds ~w(prayer announcement meditation verse)
  @forms ~w(rosary chaplet)
  @label_keys ~w(our_father hail_mary glory_be)

  @doc """
  What is wrong with `script` (the file's `"script"` object, string keys),
  given the prayer ids it may name and the mystery categories it must
  cover. An empty list when nothing is.
  """
  @spec errors(term, [String.t()], [String.t()]) :: [String.t()]
  def errors(script, prayer_ids, categories) when is_map(script) do
    styles = script["styles"]
    places = places(script["pendant"])

    context = %{
      prayer_ids: prayer_ids,
      styles: if(strings?(styles), do: styles, else: []),
      places: places
    }

    List.flatten([
      style_errors(styles),
      pendant_errors(script["pendant"]),
      heading_errors(script["headings"]),
      Enum.map(@forms, &form_errors(&1, script[&1], context)),
      extra_errors(script["closing_extras"], script, context),
      category_errors(script, categories)
    ])
  end

  def errors(_script, _prayer_ids, _categories), do: ["needs a \"script\" object"]

  defp style_errors(styles) do
    if strings?(styles) and styles != [] and "meditation" in styles,
      do: [],
      else: ["styles must list the styles a Rosary is said in, meditation among them"]
  end

  defp places(pendant) when is_list(pendant), do: for(%{"place" => place} <- pendant, do: place)
  defp places(_pendant), do: []

  defp pendant_errors(pendant) when is_list(pendant) and pendant != [] do
    places = places(pendant)

    shape =
      for {place, index} <- Enum.with_index(pendant),
          not (is_map(place) and is_binary(place["place"]) and is_binary(place["name"])),
          do: "pendant[#{index}] needs a place and a name"

    if Enum.uniq(places) == places, do: shape, else: ["pendant names a place twice" | shape]
  end

  defp pendant_errors(_pendant), do: ["pendant must list the places on the pendant"]

  defp heading_errors(%{"opening" => opening, "closing" => closing})
       when is_binary(opening) and is_binary(closing),
       do: []

  defp heading_errors(_headings), do: ["headings needs an opening and a closing"]

  defp form_errors(name, form, context) when is_map(form) do
    {strand_errors, glory_be_bead} = strand_errors(name, form["strand"])

    [
      if(strings?(form["categories"]), do: [], else: "#{name}.categories must list categories"),
      if(is_boolean(form["takes_extras"]),
        do: [],
        else: "#{name}.takes_extras must be true or false"
      ),
      strand_errors,
      part_errors("#{name}.opening", form["opening"], fn _index -> 0 end, context),
      decade_errors(name, form["decade"], glory_be_bead, context),
      part_errors("#{name}.closing", form["closing"], fn _index -> glory_be_bead end, context),
      part_errors("#{name}.final", form["final"], fn _index -> glory_be_bead end, context)
    ]
  end

  defp form_errors(name, _form, _context), do: ["#{name} is missing"]

  # The bead rules, and the bead the Glory Be is said on, which the steps'
  # own beads must agree with.
  defp strand_errors(name, %{} = strand) do
    where = "#{name}.strand"

    errors = [
      number_errors(where, strand),
      failed([
        {is_boolean(strand["fatima_prayer"]), "#{where}.fatima_prayer must be true or false"},
        {labels?(strand["labels"], &is_binary/1), "#{where}.labels needs #{label_list()}"},
        {labels?(strand["label_lines"], &(strings?(&1) and &1 != [])),
         "#{where}.label_lines needs #{label_list()}"},
        {strand_labels?(strand["strand_labels"]),
         "#{where}.strand_labels needs our_father and amen"}
      ])
    ]

    glory_be_bead = if is_integer(strand["hail_marys"]), do: strand["hail_marys"] + 1
    {errors, glory_be_bead}
  end

  defp strand_errors(name, _strand), do: {["#{name}.strand is missing"], nil}

  defp number_errors(where, strand) do
    numbers = ~w(decades hail_marys decade_length beads glory_be_bead)

    case Enum.reject(numbers, &(is_integer(strand[&1]) and strand[&1] > 0)) do
      [] ->
        %{"decades" => d, "hail_marys" => h, "decade_length" => l, "beads" => b} = strand

        failed([
          {l == h + 1, "#{where}.decade_length must be hail_marys + 1"},
          {strand["glory_be_bead"] == h + 1, "#{where}.glory_be_bead must be hail_marys + 1"},
          {b == d * l + 1, "#{where}.beads must be decades * decade_length + 1"}
        ])

      missing ->
        "#{where} needs #{Enum.join(missing, ", ")} as positive whole numbers"
    end
  end

  defp labels?(%{} = labels, valid?), do: Enum.all?(@label_keys, &valid?.(labels[&1]))
  defp labels?(_labels, _valid?), do: false

  defp label_list, do: Enum.join(@label_keys, ", ")

  defp strand_labels?(%{"our_father" => o, "amen" => a}), do: is_binary(o) and is_binary(a)
  defp strand_labels?(_labels), do: false

  # A decade is said on its Our Father bead until its run of steps said
  # on each Hail Mary, and on its Glory Be bead after it.
  defp decade_errors(name, steps, glory_be_bead, context) when is_list(steps) do
    runs = steps |> Enum.chunk_by(&per_bead?/1) |> Enum.count(&per_bead?(hd(&1)))
    run_ends = Enum.find_index(Enum.reverse(steps), &per_bead?/1)
    after_run = if run_ends, do: length(steps) - run_ends, else: length(steps)

    [
      if(runs == 1,
        do: [],
        else: "#{name}.decade needs one run of steps said on each Hail Mary, not #{runs}"
      ),
      part_errors(
        "#{name}.decade",
        steps,
        &if(&1 < after_run, do: 0, else: glory_be_bead),
        context,
        per_bead?: true
      )
    ]
  end

  defp decade_errors(name, _steps, _glory_be_bead, _context),
    do: "#{name}.decade must list its steps"

  defp part_errors(where, steps, bead_at, context, opts \\ [])

  defp part_errors(where, [_ | _] = steps, bead_at, context, opts) do
    for {step, index} <- Enum.with_index(steps),
        error <- step_errors(step, bead_at.(index), context, opts),
        do: "#{where}[#{index}] #{error}"
  end

  defp part_errors(where, _steps, _bead_at, _context, _opts), do: "#{where} must list its steps"

  defp step_errors(%{} = step, bead, context, opts) do
    in_decade? = Keyword.get(opts, :per_bead?, false)

    failed([
      {step["kind"] in @kinds, "kind must be one of #{Enum.join(@kinds, ", ")}"},
      {in_decade? or step["kind"] == "prayer", "is on the pendant, so it must be a prayer"},
      {says_its_prayer?(step, context.prayer_ids),
       "names a prayer id it cannot say, or one where it says no prayer"},
      {is_binary(step["caption"]), "needs a caption"},
      {step["place"] in [nil | context.places], "names a place not on the pendant"},
      {step["style"] in [nil | context.styles], "names a style not in styles"},
      {is_integer(step["pause_ms"]) and step["pause_ms"] >= 0, "needs a pause_ms"}
    ]) ++ List.wrap(bead_error(step, bead, in_decade?))
  end

  defp step_errors(_step, _bead, _context, _opts), do: ["must be an object"]

  # A prayer step names a prayer the file's prayers hold; any other step
  # names none.
  defp says_its_prayer?(%{"kind" => "prayer"} = step, prayer_ids),
    do: step["prayer_id"] in prayer_ids

  defp says_its_prayer?(step, _prayer_ids), do: step["prayer_id"] == nil

  defp bead_error(%{"per_bead" => per_bead}, _bead, _in_decade?) when not is_boolean(per_bead),
    do: "needs per_bead, true or false"

  defp bead_error(%{"per_bead" => true}, _bead, false),
    do: "is said on each Hail Mary outside a decade"

  defp bead_error(%{"per_bead" => true, "bead" => nil}, _bead, true), do: nil

  defp bead_error(%{"per_bead" => true}, _bead, true),
    do: "is said on each Hail Mary's bead, so its bead is null"

  defp bead_error(%{"bead" => bead}, bead, _in_decade?), do: nil

  defp bead_error(step, bead, _in_decade?),
    do: "is said on bead #{inspect(step["bead"])}, not #{inspect(bead)}"

  defp per_bead?(%{"per_bead" => true}), do: true
  defp per_bead?(_step), do: false

  defp failed(checks), do: for({false, message} <- checks, do: message)

  # The optional prayers after the Rosary: whole entries, ids once each,
  # said on the Glory Be bead of every form that takes them.
  defp extra_errors(extras, script, context) when is_list(extras) do
    beads =
      for name <- @forms,
          %{"takes_extras" => true, "strand" => %{"hail_marys" => h}} <- [script[name]],
          is_integer(h),
          uniq: true,
          do: h + 1

    ids = for %{"id" => id} <- extras, do: id
    bead = if length(beads) == 1, do: hd(beads), else: :forms_disagree

    [
      failed([
        {Enum.uniq(ids) == ids, "closing_extras names an id twice"},
        {length(beads) <= 1, "the forms that take closing_extras disagree on the Glory Be bead"}
      ]),
      for(
        {extra, index} <- Enum.with_index(extras),
        do: extra_entry_errors(extra, index, bead, context)
      )
    ]
  end

  defp extra_errors(_extras, _script, _context),
    do: "closing_extras must list the optional prayers"

  defp extra_entry_errors(
         %{"id" => id, "title" => t, "short_title" => s, "detail" => d, "steps" => steps},
         index,
         bead,
         context
       )
       when is_binary(id) and is_binary(t) and is_binary(s) and is_binary(d),
       do: part_errors("closing_extras[#{index}] (#{id})", steps, fn _index -> bead end, context)

  defp extra_entry_errors(_extra, index, _bead, _context),
    do: "closing_extras[#{index}] needs an id, a title, a short_title, a detail and steps"

  defp category_errors(script, categories) do
    named =
      for name <- @forms,
          %{"categories" => listed} <- [script[name]],
          is_list(listed),
          category <- listed,
          do: category

    if Enum.sort(named) == Enum.sort(categories),
      do: [],
      else: "every category belongs to exactly one form: #{Enum.join(categories, ", ")}"
  end

  defp strings?(list), do: is_list(list) and Enum.all?(list, &is_binary/1)
end
