defmodule LumenViae.Rosary.ContextRulesTest do
  @moduledoc """
  Enforces the rules the domains follow, as described in
  `docs/ARCHITECTURE.md` ("These rules are tested").

  These are structural rules, so they are checked by reading source files
  rather than by calling code. Without a test, a rule like "nothing outside
  the domain names a resource" survives exactly as long as everyone
  remembers it; this one fails the build.

  The four Rosary rules:

    1. Nothing outside `lib/lumen_viae/rosary/` names a Rosary resource,
       a module beneath one, or any other module of the domain's. Outside
       code calls `LumenViae.Rosary` and the value modules, and nothing
       else beneath `LumenViae.Rosary`.
    2. Nothing outside a domain calls `Ash`, or builds an `AshPhoenix.Form`
       itself. Add a code interface.
    3. Nothing touches the Repo or `Ecto.Query` for Rosary data. Queries
       are read actions, filters, preparations, aggregates and calculations
       on the resource. `release.ex` keeps `Ecto.Migrator`.
    4. Cross-resource composition uses relationships, not joins written by
       hand.

  The Office and Accounts domains follow rule 1 too: nothing outside
  `lib/lumen_viae/office/` names an Office module, and nothing outside
  `lib/lumen_viae/accounts/` names an Accounts resource.

  A module is "named" in any of the three forms Elixir allows: the full
  name, a brace alias (`alias LumenViae.Rosary.{Meditation, Voices}`) and
  the short form after an alias of the domain (`Rosary.Meditation`).
  Documentation does not count: `@moduledoc`, `@doc`, `@typedoc` and
  `@shortdoc` strings and whole-line comments are stripped before any
  rule looks at a file, so a doc may explain which internal module does
  what without the test taking it for a call.

  Each scanner is a function from a source string to its offenders, and
  the "scanner" block at the end proves on short snippets that every gap
  the audit found (docs/ASH_ROADMAP.md, B1-B4) stays closed.
  """
  use ExUnit.Case, async: true

  @domain_root "lib/lumen_viae/rosary"
  @domain "lib/lumen_viae/rosary.ex"

  # Every file under lib/lumen_viae/rosary/ that `use Ash.Resource`s. The
  # existence test below checks the list against the tree, so a new
  # resource must be added here to be guarded.
  @resources ~w(
    mystery meditation meditation_set set_membership completion author
    narration narration_voice spoken_rosary category_card rosary_content
    rosary_script prayer_book chant_library consecration true_devotion carlo_acutis
    marian_library spiritual_reading
  )

  # The resources AshPaperTrail versions. Each has a generated
  # `<Resource>.Version` resource, which rule 1 catches as a module beneath
  # its parent.
  @versioned ~w(author meditation meditation_set mystery)

  # Value modules hold shared vocabulary and pure calculation, not state or
  # queries, so any layer may call them (see docs/ARCHITECTURE.md, "Value
  # modules").
  @value_modules ~w(categories labels artwork voices prayer_audio content library)

  defp module_name(name), do: "LumenViae.Rosary." <> Macro.camelize(name)

  defp value_module_names, do: Enum.map(@value_modules, &module_name/1)

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

  # Whether a path is one domain's own: its module file (`office.ex`) or
  # anything in its folder. The slash matters: `lib/lumen_viae/office_*.ex`
  # would be outside.
  defp in_domain?(path, name) do
    path == "lib/lumen_viae/#{name}.ex" or String.starts_with?(path, "lib/lumen_viae/#{name}/")
  end

  defp outside_domain, do: Enum.reject(lib_files(), &in_domain?(&1, "rosary"))

  defp read(path), do: {path, File.read!(path)}

  defp report(offenders), do: Enum.map_join(offenders, "\n", &"  - #{&1}")

  # -- Documentation does not count -----------------------------------------

  # A documentation attribute and its string: a heredoc (plain or ~S/~s)
  # or a one-line string.
  @doc_attribute ~r/@(?:moduledoc|doc|typedoc|shortdoc)\s+(?:~[sS])?(?:"""\n.*?"""|"(?:[^"\\\n]|\\.)*")/s
  # Any line that begins with `#`, wherever it is: a line of a multi-line
  # string or a ~H template that begins with an interpolation (`#{...}`)
  # is dropped too. Accepted: that line is not a call either, and telling a
  # comment from a string would need a parser where a regex does.
  @line_comment ~r/^[ \t]*#.*$/m

  defp without_documentation(source) do
    source
    |> String.replace(@doc_attribute, "")
    |> String.replace(@line_comment, "")
  end

  # -- Naming a module ------------------------------------------------------

  # Every module beneath `root` that the source names, as full names, in
  # any of the three forms: `LumenViae.Rosary.Meditation`;
  # `alias LumenViae.Rosary.{Meditation, Voices}`; and `Rosary.Meditation`
  # after `alias LumenViae.Rosary`. The root alone (the domain) is not
  # beneath itself, so it never counts.
  defp modules_named_under(source, root) do
    source = without_documentation(source)
    short = root |> String.split(".") |> List.last()
    beneath = ~r/((?:\.[A-Z][A-Za-z0-9_]*)+)(?![A-Za-z0-9_])/
    not_after_a_dot = ~r/(?<![A-Za-z0-9_.])/

    full = ~r/#{not_after_a_dot.source}#{Regex.escape(root)}#{beneath.source}/
    short_form = ~r/#{not_after_a_dot.source}#{short}#{beneath.source}/
    brace_alias = ~r/\balias\s+#{Regex.escape(root)}\.\{([^}]*)\}/

    named =
      for regex <- [full, short_form],
          [_match, rest] <- Regex.scan(regex, source),
          do: root <> rest

    aliased =
      for [_match, inner] <- Regex.scan(brace_alias, source),
          name <- String.split(inner, ","),
          name = String.trim(name),
          name != "",
          do: root <> "." <> name

    Enum.uniq(named ++ aliased)
  end

  defp beneath?(module, parent),
    do: module == parent or String.starts_with?(module, parent <> ".")

  # Rule 1's scanner: every module of the domain's that a source names,
  # other than the value modules: a resource, a module beneath one
  # (`Completion.RateLimit`, `Meditation.Version`), an error, a type.
  defp rosary_internals_named(source) do
    for module <- modules_named_under(source, "LumenViae.Rosary"),
        module not in value_module_names(),
        do: module
  end

  # The Office check's scanner: every Office module a source names.
  defp office_modules_named(source), do: modules_named_under(source, "LumenViae.Office")

  # The Accounts check's scanner: the two Accounts resources, and the
  # modules beneath them, that a source names. `Accounts.Checks.ActorIsAdmin`
  # is not a resource, and every resource's policies name it.
  defp accounts_resources_named(source) do
    for module <- modules_named_under(source, "LumenViae.Accounts"),
        Enum.any?(
          ["LumenViae.Accounts.Admin", "LumenViae.Accounts.Token"],
          &beneath?(module, &1)
        ),
        do: module
  end

  # -- Calling Ash ----------------------------------------------------------

  # The Ash modules outside code may call: errors, the Plug helpers that
  # put an actor on a conn, and UUIDs (`limits.ex`). Anything beneath one
  # of these is allowed with it.
  @ash_allowed ~w(Ash.Error Ash.PlugHelpers Ash.UUID)

  # A function call anywhere under `Ash`: `Ash.read_one`, `Ash.Query.filter`,
  # `Ash.Resource.Info.action`, `Ash.UUID.generate`.
  @ash_function ~r/(?<![A-Za-z0-9_.])Ash((?:\.[A-Z][A-Za-z0-9_]*)*)\.([a-z_][A-Za-z0-9_]*[?!]?)/
  # The builders by name, so `require Ash.Query` and a bare struct count too.
  @ash_builder ~r/(?<![A-Za-z0-9_.])Ash\.(?:Query|Changeset|ActionInput)(?![A-Za-z0-9_])/
  @ash_form ~r/\bAshPhoenix\.Form\.for_[a-z_]+/

  # Rule 2's scanner: every Ash call, builder and form a source makes that
  # is not under an allowed module.
  defp ash_calls(source) do
    source = without_documentation(source)

    functions =
      for [call, modules, _function] <- Regex.scan(@ash_function, source),
          not Enum.any?(@ash_allowed, &beneath?("Ash" <> modules, &1)),
          do: call

    builders = @ash_builder |> Regex.scan(source) |> List.flatten()
    forms = @ash_form |> Regex.scan(source) |> List.flatten()

    Enum.uniq(functions ++ builders ++ forms)
  end

  # -- Touching the Repo ----------------------------------------------------

  @repo_use ~r/\bRepo\.\w|\bEcto\.Query\b|\bimport Ecto\b/

  # Rule 3's scanner.
  defp uses_repo?(source), do: Regex.match?(@repo_use, without_documentation(source))

  # The source of every `from(x in <source>` in a file, as written.
  @query_source ~r/\bfrom\s*\(?\s*\w+\s+in\s+([A-Za-z][A-Za-z0-9_.]*|"[^"]*")/

  defp queries_not_on(source, schema) do
    for [_match, from] <- Regex.scan(@query_source, without_documentation(source)),
        from != schema,
        do: from
  end

  # -- The tree -------------------------------------------------------------

  test "every resource exists, one file each, and the list here is complete" do
    for name <- @resources do
      assert File.exists?("#{@domain_root}/#{name}.ex"), "missing resource: #{name}.ex"
    end

    assert File.exists?(@domain)

    in_tree =
      for path <- Path.wildcard("#{@domain_root}/*.ex"),
          File.read!(path) =~ ~r/^\s*use Ash\.Resource\b/m,
          do: Path.basename(path, ".ex")

    assert Enum.sort(in_tree) == Enum.sort(@resources),
           "the resources in the tree and in @resources differ; add the new one to the list"

    versioned =
      for name <- @resources,
          File.read!("#{@domain_root}/#{name}.ex") =~ ~r/^\s*paper_trail do\b/m,
          do: name

    assert Enum.sort(versioned) == Enum.sort(@versioned),
           "the resources with a paper_trail block and @versioned differ"
  end

  test "rule 1: nothing outside the domain names a Rosary resource, or any other module of the domain's" do
    offenders =
      for {path, source} <- Enum.map(outside_domain(), &read/1),
          module <- rosary_internals_named(source),
          do: "#{path} -> #{module}"

    assert offenders == [],
           """
           Resources and everything else beneath LumenViae.Rosary are private \
           to the domain; only LumenViae.Rosary itself and the value modules \
           (#{Enum.join(@value_modules, ", ")}) may be named. Call the domain's \
           code interface instead:

           #{report(offenders)}
           """
  end

  # Each of these is an Ash domain of its own, whose resources, changes,
  # checks and action implementations call Ash on their own resources, not
  # Rosary ones. Rules 1 and 3 and the Office and Accounts checks still
  # cover them.
  @own_domains [
    "office",
    "accounts",
    # Ops: generic actions on LumenViae.Ops.Maintenance, and
    # Ash.Domain.Info in ops/jobs.ex to list every domain's AshOban triggers.
    "ops"
  ]

  # Calls allowed by name in one file, each with its reason.
  @ash_calls_allowed %{
    # Dev only: signs the seeded admin in without a password
    # (config :lumen_viae, :skip_admin_auth), so the token has to be put
    # on the record the way AshAuthentication's own sign-in does.
    "lib/lumen_viae_web/plugs/require_admin.ex" => ["Ash.Resource.put_metadata"],
    # Reads the definition of each v2 route's action and calculations to
    # correct the OpenAPI document AshJsonApi generates: introspection of a
    # resource the router handed it, never a read or a write, and nothing
    # a code interface could answer.
    "lib/lumen_viae_web/json_api/open_api.ex" => [
      "Ash.Resource.Info.action",
      "Ash.Resource.Info.public_calculations"
    ]
  }

  test "rule 2: nothing outside a domain calls Ash or builds an Ash form itself" do
    offenders =
      for {path, source} <- Enum.map(outside_domain(), &read/1),
          not Enum.any?(@own_domains, &in_domain?(path, &1)),
          call <- ash_calls(source) -- Map.get(@ash_calls_allowed, path, []),
          do: "#{path} -> #{call}"

    assert offenders == [],
           """
           Only the domain calls Ash on a Rosary resource. Add a code interface \
           to LumenViae.Rosary, or use its form_to_* functions:

           #{report(offenders)}
           """
  end

  # audio_jobs.ex reads Oban's own jobs table (oban_jobs), which is not
  # Rosary data and has no resource to give it a read action. The
  # exception covers only queries on Oban.Job; see the next test.
  @audio_jobs "lib/lumen_viae/curation/audio_jobs.ex"

  # The completion tallies are grouped queries over the one table their
  # resource owns (Ash has no GROUP BY), inside the resource, behind its
  # generic actions and their policies. They may use Ecto, never a join.
  @grouped_queries [
    "#{@domain_root}/completion/daily_counts.ex",
    "#{@domain_root}/completion/place_counts.ex"
  ]

  test "rule 3: nothing touches the Repo or Ecto.Query for Rosary data" do
    # The Office owns no tables and never touches the Repo; the Ops domain
    # reads the jobs table, Postgres's catalogs and statistics views, and
    # nothing of the Rosary's.
    allowed =
      ["lib/lumen_viae/repo.ex", "lib/lumen_viae/release.ex", @audio_jobs | @grouped_queries]

    offenders =
      for {path, source} <- Enum.map(lib_files(), &read/1),
          path not in allowed,
          not in_domain?(path, "office"),
          not in_domain?(path, "ops"),
          uses_repo?(source),
          do: path

    assert offenders == [],
           """
           Rosary data is read and written through the resources' actions, \
           never through the Repo:

           #{report(offenders)}
           """
  end

  test "rule 3: the audio jobs module queries only Oban's jobs table" do
    {_path, source} = read(@audio_jobs)

    assert queries_not_on(source, "Oban.Job") == [],
           "#{@audio_jobs} may query Oban.Job only; Rosary data goes through the domain"
  end

  test "rule 4: the resources compose through relationships, not joins written by hand" do
    for path <- @grouped_queries do
      {_path, source} = read(path)

      refute Regex.match?(~r/\bjoin:|\bjoin\(/, without_documentation(source)),
             "#{path} joins another table"
    end

    offenders =
      for {path, source} <-
            Enum.map(Path.wildcard("#{@domain_root}/**/*.ex") ++ [@domain], &read/1),
          path not in @grouped_queries,
          Regex.match?(
            ~r/\bEcto\.Query\b|\bjoin:|\bfrom\s*\(?\s*\w+\s+in\s/,
            without_documentation(source)
          ),
          do: path

    assert offenders == [],
           "write the cross-resource rule as an expression on the resource: #{inspect(offenders)}"
  end

  # The Office domain follows rule 1 too: nothing outside
  # lib/lumen_viae/office/ names its internals. The supervision tree is
  # the one exception: application.ex starts LumenViae.Office.Cache.
  @office_exceptions ["lib/lumen_viae/application.ex"]

  test "nothing outside the Office domain names an Office module" do
    offenders =
      for {path, source} <- Enum.map(lib_files(), &read/1),
          not in_domain?(path, "office"),
          path not in @office_exceptions,
          module <- office_modules_named(source),
          do: "#{path} -> #{module}"

    assert offenders == [],
           """
           Office modules are private to LumenViae.Office. Call its public \
           functions instead:

           #{report(offenders)}
           """
  end

  # The Accounts domain follows rule 1 too. The router is the one exception:
  # AshAuthentication's `auth_routes` macro must name the admin resource.
  # AshPaperTrail's `belongs_to_actor` names it too, on the content
  # resources whose versions record who made them: a relationship across
  # the two domains, declared, not a call around one.
  @actor_relationship ~r/^\s*belongs_to_actor :admin, LumenViae\.Accounts\.Admin,.*$/m

  test "nothing outside the Accounts domain names an Accounts resource" do
    offenders =
      for {path, source} <- Enum.map(lib_files(), &read/1),
          not in_domain?(path, "accounts"),
          path != "lib/lumen_viae_web/router.ex",
          source = String.replace(source, @actor_relationship, ""),
          module <- accounts_resources_named(source),
          do: "#{path} -> #{module}"

    assert offenders == [],
           """
           Accounts resources are private to LumenViae.Accounts. Call its \
           code interface instead:

           #{report(offenders)}
           """
  end

  # -- The scanners, on snippets --------------------------------------------
  #
  # One case per gap the audit found (docs/ASH_ROADMAP.md, B1-B4), so the
  # test of the test is not a manual plant-and-remove.

  describe "the scanner" do
    test "B1: sees a brace alias" do
      snippet = ~S"""
      alias LumenViae.Rosary.{Meditation, Voices}
      """

      assert rosary_internals_named(snippet) == ["LumenViae.Rosary.Meditation"]
    end

    test "B1: sees the short form after an alias of the domain" do
      snippet = ~S"""
      alias LumenViae.Rosary
      Rosary.Meditation |> Ash.Query.filter(archived == false)
      """

      assert rosary_internals_named(snippet) == ["LumenViae.Rosary.Meditation"]
    end

    test "B1: a value module and the domain itself are not resources" do
      snippet = ~S"""
      alias LumenViae.Rosary
      alias LumenViae.Rosary.{Categories, Voices}
      Rosary.list_meditations!() |> Enum.map(&Rosary.Categories.label(&1.category))
      """

      assert rosary_internals_named(snippet) == []
    end

    test "B2: sees a module beneath a resource, a version resource and an error" do
      snippet = ~S"""
      LumenViae.Rosary.Completion.RateLimit.check(conn)
      Ash.read!(LumenViae.Rosary.Meditation.Version)
      alias LumenViae.Rosary.Errors.AudioUnavailable
      """

      assert rosary_internals_named(snippet) == [
               "LumenViae.Rosary.Completion.RateLimit",
               "LumenViae.Rosary.Meditation.Version",
               "LumenViae.Rosary.Errors.AudioUnavailable"
             ]
    end

    test "B2: sees the newer resources, and a whole name only" do
      assert rosary_internals_named("LumenViae.Rosary.NarrationVoice") ==
               ["LumenViae.Rosary.NarrationVoice"]

      assert rosary_internals_named("LumenViae.Rosary.MeditationSet") ==
               ["LumenViae.Rosary.MeditationSet"]
    end

    test "B3: sees every function under Ash, the builders and any AshPhoenix form" do
      snippet = ~S"""
      Ash.read_one(query)
      Ash.Resource.put_metadata(record, :token, token)
      require Ash.Query
      %Ash.ActionInput{}
      AshPhoenix.Form.for_read(resource, :search)
      """

      assert ash_calls(snippet) == [
               "Ash.read_one",
               "Ash.Resource.put_metadata",
               "Ash.Query",
               "Ash.ActionInput",
               "AshPhoenix.Form.for_read"
             ]
    end

    test "B3: errors, the Plug helpers and UUIDs are allowed" do
      snippet = ~S"""
      {:error, %Ash.Error.Invalid{} = error} -> Ash.Error.Invalid.exception(errors: [])
      Ash.PlugHelpers.set_actor(conn, admin)
      Ash.UUID.generate()
      """

      assert ash_calls(snippet) == []
    end

    test "B3: the audio jobs exception covers only queries on Oban.Job" do
      snippet = ~S"""
      from(j in Oban.Job, where: j.state == "available")
      from m in "meditations", select: m.id
      from(m in LumenViae.Rosary.Meditation)
      """

      assert queries_not_on(snippet, "Oban.Job") == [
               ~s("meditations"),
               "LumenViae.Rosary.Meditation"
             ]
    end

    test "B4: sees an Office module outside the Office, in every form" do
      snippet = ~S"""
      alias LumenViae.Office
      alias LumenViae.Office.{Parser, Versions}
      Office.Cache.reset()
      LumenViae.Office.Jobs.WarmCache.new(%{})
      """

      assert office_modules_named(snippet) == [
               "LumenViae.Office.Jobs.WarmCache",
               "LumenViae.Office.Cache",
               "LumenViae.Office.Parser",
               "LumenViae.Office.Versions"
             ]
    end

    test "documentation does not count" do
      snippet = ~S'''
      defmodule LumenViae.Limits do
        @moduledoc """
        The completion limit is the resource's own
        (`LumenViae.Rosary.Completion.RateLimit`); Ash.read(query) is not
        called here, nor is `LumenViae.Office.Parser`.
        """

        @doc "Names `Rosary.Meditation` and `Office.Cache` in one line."
        # A comment naming LumenViae.Rosary.Meditation.Version, Ash.Query
        # and from(m in "meditations") does not count either.
        def limit, do: Ash.UUID.generate()
      end
      '''

      assert rosary_internals_named(snippet) == []
      assert office_modules_named(snippet) == []
      assert ash_calls(snippet) == []
      assert queries_not_on(snippet, "Oban.Job") == []
      refute uses_repo?(snippet)
    end
  end
end
