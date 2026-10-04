defmodule LumenViae.Rosary.ContextRulesTest do
  @moduledoc """
  Enforces the rules the Rosary domain follows, as described in
  `docs/ARCHITECTURE.md` and restated for Ash in `docs/ASH_MIGRATION.md`.

  These are structural rules, so they are checked by reading source files
  rather than by calling code. Without a test, a rule like "nothing outside
  the domain names a resource" survives exactly as long as everyone
  remembers it; this one fails the build.

  The four rules:

    1. Nothing outside `lib/lumen_viae/rosary/` names a Rosary resource.
       Outside code calls `LumenViae.Rosary` and the value modules.
    2. Nothing outside the domain calls `Ash` on a Rosary resource, or
       builds an `AshPhoenix.Form` for one directly. Add a code interface.
    3. Nothing touches the Repo or `Ecto.Query` for Rosary data. Queries
       are read actions, filters, preparations, aggregates and calculations
       on the resource. `release.ex` keeps `Ecto.Migrator`.
    4. Cross-resource composition uses relationships, not joins written by
       hand.
  """
  use ExUnit.Case, async: true

  @domain_root "lib/lumen_viae/rosary"
  @domain "lib/lumen_viae/rosary.ex"

  @resources ~w(mystery meditation meditation_set set_membership completion author narration)

  # Value modules hold shared vocabulary and pure calculation, not state or
  # queries, so any layer may call them (see docs/ARCHITECTURE.md, "Value
  # modules").
  @value_modules ~w(categories labels artwork voices prayer_audio content)

  defp module_name(name), do: "LumenViae.Rosary." <> Macro.camelize(name)

  # The modules the web layer may name besides the domain itself.
  defp web_allowed, do: ["LumenViae.Rosary" | Enum.map(@value_modules, &module_name/1)]

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

  defp outside_domain do
    Enum.reject(lib_files(), &(String.starts_with?(&1, @domain_root) or &1 == @domain))
  end

  defp read(path), do: {path, File.read!(path)}

  # Matches a fully qualified reference, so `LumenViae.Rosary.Meditation`
  # does not also match `LumenViae.Rosary.MeditationSet`.
  defp references?(source, module) do
    Regex.match?(~r/#{Regex.escape(module)}(?![A-Za-z0-9_.])/, source)
  end

  test "the seven table-backed resources exist, one file each" do
    for name <- @resources do
      assert File.exists?("#{@domain_root}/#{name}.ex"), "missing resource: #{name}.ex"
    end

    assert File.exists?(@domain)
  end

  test "rule 1: nothing outside the domain names a Rosary resource" do
    resources = Enum.map(@resources, &module_name/1)

    offenders =
      for {path, source} <- Enum.map(outside_domain(), &read/1),
          resource <- resources,
          references?(source, resource),
          do: "#{path} -> #{resource}"

    assert offenders == [],
           """
           Resources are private to LumenViae.Rosary. Call the domain's code \
           interface instead:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  test "rule 2: nothing outside the domain calls Ash or builds an Ash form itself" do
    offenders =
      for {path, source} <- Enum.map(outside_domain(), &read/1),
          not String.starts_with?(path, "lib/lumen_viae/office"),
          Regex.match?(
            ~r/\bAsh\.(read|get|create|update|destroy|load|count|exists\?|bulk_\w+|Query|Changeset)\b/,
            source
          ) or
            Regex.match?(~r/AshPhoenix\.Form\.for_(create|update|action|destroy)\b/, source),
          do: path

    assert offenders == [],
           """
           Only the domain calls Ash on a Rosary resource. Add a code interface \
           to LumenViae.Rosary, or use its form_to_* functions:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  test "rule 3: nothing touches the Repo or Ecto.Query for Rosary data" do
    # audio_jobs.ex counts Oban's own jobs table (oban_jobs), which is not
    # Rosary data and has no resource to give it a read action. The Ops
    # domain (lib/lumen_viae/ops/) reads the same table, Postgres's
    # catalogs and statistics views, and nothing of the Rosary's.
    allowed = [
      "lib/lumen_viae/repo.ex",
      "lib/lumen_viae/release.ex",
      "lib/lumen_viae/curation/audio_jobs.ex",
      # Ash has no GROUP BY: the completion tallies are grouped Ecto
      # queries inside the resource that owns the table, behind its
      # generic actions and their policies.
      "lib/lumen_viae/rosary/completion/daily_counts.ex",
      "lib/lumen_viae/rosary/completion/place_counts.ex"
    ]

    offenders =
      for {path, source} <- Enum.map(lib_files(), &read/1),
          path not in allowed,
          not String.starts_with?(path, "lib/lumen_viae/office"),
          not String.starts_with?(path, "lib/lumen_viae/ops/"),
          Regex.match?(~r/\bRepo\.\w|\bEcto\.Query\b|import Ecto\b/, source),
          do: path

    assert offenders == [],
           """
           Rosary data is read and written through the resources' actions, \
           never through the Repo:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  # The completion tallies are grouped queries over the one table their
  # resource owns (Ash has no GROUP BY). They may use Ecto, never a join.
  @grouped_queries [
    "#{@domain_root}/completion/daily_counts.ex",
    "#{@domain_root}/completion/place_counts.ex"
  ]

  test "rule 4: the resources compose through relationships, not joins written by hand" do
    for path <- @grouped_queries do
      {_path, source} = read(path)
      refute Regex.match?(~r/\bjoin:|\bjoin\(/, source), "#{path} joins another table"
    end

    offenders =
      for {path, source} <-
            Enum.map(Path.wildcard("#{@domain_root}/**/*.ex") ++ [@domain], &read/1),
          path not in @grouped_queries,
          Regex.match?(~r/\bEcto\.Query\b|\bjoin:|\bfrom\s*\(?\s*\w+\s+in\s/, source),
          do: path

    assert offenders == [],
           "write the cross-resource rule as an expression on the resource: #{inspect(offenders)}"
  end

  # The Accounts domain follows rule 1 too. The router is the one exception:
  # AshAuthentication's `auth_routes` macro must name the admin resource.
  # `LumenViae.Accounts.Checks.ActorIsAdmin` is not a resource, and every
  # resource's policies name it. AshPaperTrail's `belongs_to_actor` names
  # it too, on the content resources whose versions record who made them:
  # a relationship across the two domains, declared, not a call around one.
  @actor_relationship ~r/^\s*belongs_to_actor :admin, LumenViae\.Accounts\.Admin,.*$/m

  test "nothing outside the Accounts domain names an Accounts resource" do
    offenders =
      for path <- lib_files(),
          not String.starts_with?(path, "lib/lumen_viae/accounts"),
          path != "lib/lumen_viae_web/router.ex",
          {_path, source} = read(path),
          source = String.replace(source, @actor_relationship, ""),
          resource <- ["LumenViae.Accounts.Admin", "LumenViae.Accounts.Token"],
          references?(source, resource),
          do: "#{path} -> #{resource}"

    assert offenders == [],
           """
           Accounts resources are private to LumenViae.Accounts. Call its \
           code interface instead:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end

  test "value modules are the only domain modules the web layer may name directly" do
    web_files =
      Path.wildcard("lib/lumen_viae_web/**/*.ex") ++
        Path.wildcard("lib/lumen_viae_web/**/*.heex")

    offenders =
      for {path, source} <- Enum.map(web_files, &read/1),
          module <-
            Regex.scan(~r/LumenViae\.Rosary(?:\.[A-Z][A-Za-z0-9_]*)*/, source)
            |> Enum.map(&hd/1)
            |> Enum.uniq(),
          module not in web_allowed(),
          do: "#{path} -> #{module}"

    assert offenders == [],
           """
           The web layer may only name LumenViae.Rosary and the value modules \
           (#{Enum.join(@value_modules, ", ")}):

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}
           """
  end
end
