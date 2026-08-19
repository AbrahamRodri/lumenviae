defmodule LumenViae.Rosary.ContextRulesTest do
  @moduledoc """
  Enforces the context rules described in `docs/ARCHITECTURE.md`.

  These are structural rules, so they are checked by reading source files
  rather than by calling code. Without a test, a rule like "only Secondary
  Contexts touch the Repo" survives exactly as long as everyone remembers
  it.
  """
  use ExUnit.Case, async: true

  @domain_root "lib/lumen_viae/rosary"
  @primary_context "lib/lumen_viae/rosary.ex"

  @secondary_contexts ~w(mysteries meditations meditation_sets set_memberships completions)

  # Value modules hold shared vocabulary, not state or queries, so any layer
  # may call them (see docs/ARCHITECTURE.md, "Value modules").
  @value_modules ~w(categories labels artwork)

  defp secondary_context_files,
    do: Enum.map(@secondary_contexts, &"#{@domain_root}/#{&1}.ex")

  defp schema_files, do: Path.wildcard("#{@domain_root}/*/*.ex")

  # priv/repo/seeds.exs is checked alongside lib/ because it is real
  # application code that `mix setup` and `LumenViae.Release.seed/0` run;
  # it is just never compiled, so a stale module reference in it would only
  # surface at runtime. Migrations are deliberately excluded: they run
  # against whatever the schema was at the time and must not depend on
  # today's modules.
  defp lib_files do
    Path.wildcard("lib/**/*.ex") ++
      Path.wildcard("lib/**/*.heex") ++
      ["priv/repo/seeds.exs"]
  end

  defp read(path), do: {path, File.read!(path)}

  defp offenders(files, predicate) do
    files
    |> Enum.map(&read/1)
    |> Enum.filter(fn {path, source} -> predicate.(path, source) end)
    |> Enum.map(&elem(&1, 0))
  end

  # Matches a fully qualified reference, so `LumenViae.Rosary.Meditations`
  # does not also match `LumenViae.Rosary.Meditations.Meditation`.
  defp references?(source, module) do
    Regex.match?(~r/#{Regex.escape(module)}(?![A-Za-z0-9_.])/, source)
  end

  defp module_name(segments), do: Enum.join(["LumenViae", "Rosary" | segments], ".")

  defp camelize(name), do: name |> Macro.camelize()

  test "the expected Secondary Contexts and schemas exist" do
    for file <- secondary_context_files() do
      assert File.exists?(file), "missing Secondary Context: #{file}"
    end

    # Every Secondary Context has exactly one schema, in its own directory.
    for name <- @secondary_contexts do
      schemas = Path.wildcard("#{@domain_root}/#{name}/*.ex")

      assert length(schemas) == 1,
             "#{name} should own exactly one schema, found: #{inspect(schemas)}"
    end

    assert File.exists?(@primary_context)
  end

  test "rule 3: only Secondary Contexts talk to the Repo" do
    allowed = ["lib/lumen_viae/repo.ex" | secondary_context_files()]

    offenders =
      offenders(lib_files(), fn path, source ->
        path not in allowed and Regex.match?(~r/\bRepo\.\w/, source)
      end)

    assert offenders == [],
           """
           These modules reach the Repo directly. Move the query into the \
           Secondary Context that owns the table:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  test "rule 1: schema modules hold no queries of their own" do
    offenders =
      offenders(schema_files(), fn _path, source -> Regex.match?(~r/\bRepo\.\w/, source) end)

    assert offenders == [],
           "schemas must stay changeset-only, but these query: #{inspect(offenders)}"
  end

  test "rule 4: nothing outside the domain calls a Secondary Context" do
    outside = Enum.reject(lib_files(), &String.starts_with?(&1, @domain_root))
    contexts = Enum.map(@secondary_contexts, &module_name([camelize(&1)]))

    offenders =
      for {path, source} <- Enum.map(outside, &read/1),
          context <- contexts,
          references?(source, context),
          do: "#{path} -> #{context}"

    assert offenders == [],
           """
           Secondary Contexts are private to LumenViae.Rosary. Add a function \
           to the Primary Context instead:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  test "rule 1: schemas are private to their own Secondary Context" do
    schemas =
      for name <- @secondary_contexts,
          schema <- Path.wildcard("#{@domain_root}/#{name}/*.ex") do
        schema_module =
          schema |> Path.basename(".ex") |> camelize() |> then(&module_name([camelize(name), &1]))

        {name, schema_module}
      end

    # A schema may be named by its own Secondary Context, by its own
    # directory (the schema itself), and by another schema declaring an Ecto
    # association - an association has to name the other module by design.
    # Nothing else may name it, not even another Secondary Context.
    offenders =
      for {path, source} <- Enum.map(lib_files(), &read/1),
          {owner, schema_module} <- schemas,
          references?(source, schema_module),
          path != "#{@domain_root}/#{owner}.ex",
          not String.starts_with?(path, "#{@domain_root}/#{owner}/"),
          not schema_file?(path),
          do: "#{path} -> #{schema_module}"

    assert offenders == [],
           """
           Schemas are private to their Secondary Context. Go through \
           LumenViae.Rosary instead:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  defp schema_file?(path), do: path in schema_files()

  test "value modules are the only domain modules the web layer may call directly" do
    web_files =
      Path.wildcard("lib/lumen_viae_web/**/*.ex") ++
        Path.wildcard("lib/lumen_viae_web/**/*.heex")

    allowed = ["LumenViae.Rosary" | Enum.map(@value_modules, &module_name([camelize(&1)]))]

    offenders =
      for {path, source} <- Enum.map(web_files, &read/1),
          module <-
            Regex.scan(~r/LumenViae\.Rosary(?:\.[A-Z][A-Za-z0-9_]*)*/, source)
            |> Enum.map(&hd/1)
            |> Enum.uniq(),
          module not in allowed,
          do: "#{path} -> #{module}"

    assert offenders == [],
           """
           The web layer may only name LumenViae.Rosary and the value modules \
           (#{Enum.join(@value_modules, ", ")}):

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end
end
