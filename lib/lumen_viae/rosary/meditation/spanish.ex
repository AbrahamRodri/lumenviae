defmodule LumenViae.Rosary.Meditation.Spanish do
  @moduledoc """
  The meditations in Spanish: what a meditation set's `translations`
  section serves with `lang=es`.

  The meditations live in the database and are edited in the console; the
  Spanish lives in `priv/meditations/es/meditations.json`, keyed by
  meditation id. Each entry holds the Spanish `title` (none where the
  English has none) and `content` and the
  `english` fingerprint (`fingerprint/2`) of the English title and text it
  translates. A meditation is served in Spanish only while its English
  still has that fingerprint: an English edit makes it fall back to the
  English until its Spanish is redone, rather than serve Spanish of words
  no longer there.

  A text is copied from a public-domain Spanish edition, or else is the
  team's translation, marked `ai_translated`; `priv/meditations/es/SOURCES.md`
  says which. Nothing here is narrated: the recordings stay English, and
  nothing in this module writes or enqueues anything.

  The file is dated and pinned in
  `test/lumen_viae/rosary/meditation/spanish_test.exs`.
  """

  alias LumenViae.Rosary.Content

  @path Path.join([:code.priv_dir(:lumen_viae), "meditations", "es", "meditations.json"])
  @external_resource @path

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/meditations/es/meditations.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  @entries Map.fetch!(file, "meditations")

  for {id, entry} <- @entries do
    match?({_, ""}, Integer.parse(id)) ||
      raise CompileError,
        description: "priv/meditations/es/meditations.json: #{inspect(id)} is not a meditation id"

    (is_map(entry) and Enum.all?(~w(content english), &(is_binary(entry[&1]) and entry[&1] != "")) and
       (is_nil(entry["title"]) or (is_binary(entry["title"]) and entry["title"] != "")) and
       Map.get(entry, "ai_translated", true) == true) ||
      raise CompileError,
        description:
          "priv/meditations/es/meditations.json: #{id} needs a content and the english fingerprint, a title or none (as the English), and \"ai_translated\" is either true or left out"
  end

  @doc """
  The fingerprint of a meditation's English title and text: the first 16
  hex digits of the SHA-256 of `title <> "\\n" <> content`. An entry
  records the fingerprint of the English it was made from.
  """
  @spec fingerprint(String.t(), String.t()) :: String.t()
  def fingerprint(title, content) do
    :crypto.hash(:sha256, title <> "\n" <> content)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  @doc """
  The Spanish of these meditations, in their order, for each one whose
  entry still matches its English: `%{id:, title:, content:}`, plus
  `ai_translated: true` where it is the team's translation. Each is a
  plain map, so the mark is there only when true. A meditation with no
  entry, or whose English has changed, is left out: show its English.
  """
  @spec translations([%{id: integer, title: String.t(), content: String.t()}]) :: [map]
  def translations(meditations) do
    entries = entries()

    for %{id: id, title: title, content: content} <- meditations,
        entry = entries["#{id}"],
        entry["english"] == fingerprint(title || "", content || "") do
      shape(id, entry)
    end
  end

  defp shape(id, %{"ai_translated" => true} = entry),
    do: %{id: id, title: entry["title"], content: entry["content"], ai_translated: true}

  defp shape(id, entry), do: %{id: id, title: entry["title"], content: entry["content"]}

  # The test suite has none of production's meditations, so a test may put
  # entries of its own here (Application.put_env); everywhere else this is
  # the file.
  defp entries, do: Application.get_env(:lumen_viae, __MODULE__, [])[:entries] || @entries

  @doc "When the file last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version, do: Content.version(%{"meditations" => @entries})

  @doc "The meditation ids the file translates."
  @spec ids() :: [integer]
  def ids, do: @entries |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.sort()
end
