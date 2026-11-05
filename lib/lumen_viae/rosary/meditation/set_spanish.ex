defmodule LumenViae.Rosary.Meditation.SetSpanish do
  @moduledoc """
  The meditation sets' own words in Spanish: a set's name, author,
  description, source and image alt text, as its `set_translation` serves
  them with `lang=es`.

  The sets live in the database and are edited in the console; the
  Spanish lives in `priv/meditations/es/sets.json`, keyed by set id. Each
  field holds its Spanish (`es`) and the `english` fingerprint
  (`fingerprint/1`) of the English it stands for, as a client is shown it:
  the name, the byline's author and source (`byline_author`,
  `byline_source`), the description and the alt text
  of the artwork the set is shown with. A field is served only while its
  English still has that fingerprint; an English edit makes it fall back
  to the English. An `english` of null stands for no English: the Spanish
  is served while the English is still empty (a set copied from a Spanish
  edition the English does not name). A field the entry leaves out has no
  Spanish.

  The names, authors, descriptions and alt texts are the team's
  translation (names in their usual Spanish forms), so a set served with
  any of them is marked `ai_translated`; a source is the
  Spanish edition's title where the Spanish was copied from one, else the
  English citation translated. `priv/meditations/es/SOURCES.md` lists
  them. Nothing here is narrated or written.

  The file is dated and pinned in
  `test/lumen_viae/rosary/meditation/set_spanish_test.exs`.
  """

  alias LumenViae.Rosary.Content

  @path Path.join([:code.priv_dir(:lumen_viae), "meditations", "es", "sets.json"])
  @external_resource @path

  # The file's field, and the key it is served under.
  @fields %{
    "name" => :name,
    "author" => :author,
    "description" => :description,
    "source" => :source,
    "image_alt" => :artwork_alt
  }

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/meditations/es/sets.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  @entries Map.fetch!(file, "sets")

  for {id, entry} <- @entries do
    match?({_, ""}, Integer.parse(id)) ||
      raise CompileError,
        description: "priv/meditations/es/sets.json: #{inspect(id)} is not a set id"

    (is_map(entry) and entry != %{} and Map.keys(entry) -- Map.keys(@fields) == [] and
       Enum.all?(entry, fn {_field, value} ->
         match?(%{"es" => es} when is_binary(es) and es != "", value) and
           Map.keys(value) -- ~w(es english) == [] and
           (is_nil(value["english"]) or is_binary(value["english"]))
       end)) ||
      raise CompileError,
        description:
          "priv/meditations/es/sets.json: #{id} needs one or more of #{Enum.join(Map.keys(@fields), ", ")}, each a Spanish \"es\" and the \"english\" fingerprint (null for no English)"
  end

  @doc """
  The fingerprint of an English text: the first 16 hex digits of its
  SHA-256, or nil for none.
  """
  @spec fingerprint(String.t() | nil) :: String.t() | nil
  def fingerprint(nil), do: nil

  def fingerprint(text) do
    :crypto.hash(:sha256, text)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  @doc """
  The Spanish of a set's name, author, description, source and artwork
  alt text, given the English a client is shown for each: `%{name:,
  author:, description:, source:, artwork_alt:, ai_translated: true}`, each field nil where it has no
  Spanish or its English has changed. Nil when the set has no Spanish at
  all, or none still matches.
  """
  @spec translation(integer, %{
          name: String.t() | nil,
          author: String.t() | nil,
          description: String.t() | nil,
          source: String.t() | nil,
          artwork_alt: String.t() | nil
        }) :: map | nil
  def translation(id, english) do
    case entries()["#{id}"] do
      nil ->
        nil

      entry ->
        spanish =
          Map.new(@fields, fn {field, key} ->
            {key, served(entry[field], Map.get(english, key))}
          end)

        if Enum.all?(Map.values(spanish), &is_nil/1),
          do: nil,
          else: Map.put(spanish, :ai_translated, true)
    end
  end

  defp served(%{"es" => es} = field, english) do
    if field["english"] == fingerprint(english), do: es
  end

  defp served(nil, _english), do: nil

  # The test suite has none of production's sets, so a test may put
  # entries of its own here (Application.put_env); everywhere else this is
  # the file.
  defp entries, do: Application.get_env(:lumen_viae, __MODULE__, [])[:entries] || @entries

  @doc "When the file last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version, do: Content.version(%{"sets" => @entries})

  @doc "The set ids the file translates."
  @spec ids() :: [integer]
  def ids, do: @entries |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.sort()
end
