defmodule LumenViae.Rosary.RosaryContent.SpanishNames do
  @moduledoc """
  The mysteries' names and fruits, and the sets' names, in Spanish:
  what `GET /api/v2/rosary-content?lang=es` serves in its `mysteries` and
  `categories` sections in place of the English.

  The words are `priv/rosary_content/es/mysteries.json`, read when this
  module compiles; where each comes from, and which are the team's own
  translation, is `priv/rosary_content/SOURCES.md`. A mystery or set the
  file does not name keeps its English. Nothing here is narrated: a
  mystery's `announcement` stays the English the spoken Rosary says.

  The file is dated (`updated_at/0`) and pinned in
  `test/lumen_viae/rosary/rosary_content/spanish_names_test.exs`: change a
  word, bump its date and the pinned version.
  """

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Content

  @path Path.join([:code.priv_dir(:lumen_viae), "rosary_content", "es", "mysteries.json"])
  @external_resource @path

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/rosary_content/es/mysteries.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  @mysteries Map.fetch!(file, "mysteries")
  @categories Map.fetch!(file, "categories")

  for {key, words} <- @mysteries do
    unless key in Categories.mystery_keys() and
             match?(
               %{"name" => name, "fruit" => fruit} when is_binary(name) and is_binary(fruit),
               words
             ) do
      raise CompileError,
        description:
          "priv/rosary_content/es/mysteries.json: #{inspect(key)} must be a mystery key with a name and a fruit"
    end
  end

  for {slug, words} <- @categories do
    unless slug in Categories.slugs() and
             match?(
               %{"name" => name, "devotion_title" => title}
               when is_binary(name) and is_binary(title),
               words
             ) do
      raise CompileError,
        description:
          "priv/rosary_content/es/mysteries.json: #{inspect(slug)} must be a category slug with a name and a devotion_title"
    end
  end

  @doc "A mystery's Spanish `name` and `fruit` by its key, or `nil`."
  @spec mystery(String.t()) :: %{name: String.t(), fruit: String.t()} | nil
  def mystery(key) do
    with %{"name" => name, "fruit" => fruit} <- Map.get(@mysteries, key),
         do: %{name: name, fruit: fruit}
  end

  @doc "A set's Spanish `name` and `devotion_title` by its slug, or `nil`."
  @spec category(String.t()) :: %{name: String.t(), devotion_title: String.t()} | nil
  def category(slug) do
    with %{"name" => name, "devotion_title" => title} <- Map.get(@categories, slug),
         do: %{name: name, devotion_title: title}
  end

  @doc "When the file last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec version() :: String.t()
  def version, do: Content.version(%{"mysteries" => @mysteries, "categories" => @categories})
end
