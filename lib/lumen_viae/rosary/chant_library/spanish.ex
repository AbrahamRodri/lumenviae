defmodule LumenViae.Rosary.ChantLibrary.Spanish do
  @moduledoc """
  The Chant Library's names in Spanish: what
  `GET /api/v2/chant-library?lang=es` serves in its `translations` section.

  `priv/library/es/chant_library.json` holds, by id, each chant's Spanish
  `title` (beside its `english_title`) and `setting`, and each group's
  `title`, `note` and its parts' headings and notes: the names and lines
  the apps print on a chant's card and row and over each section. They are the
  team's own Spanish for labels, not a published text
  (`priv/library/es/SOURCES.md`). The chants are sung in Latin, and their
  words and lines stay as they are.

  A chant has a Spanish `setting` exactly when it has an English one, so a
  client lays the two over each other field for field. A chant or group
  the file does not hold keeps its English.

  The file is dated and pinned in
  `test/lumen_viae/rosary/chant_library/spanish_test.exs`.
  """

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library

  @path Path.join([:code.priv_dir(:lumen_viae), "library", "es", "chant_library.json"])
  @external_resource @path

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/library/es/chant_library.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  english = Library.sections(:chant_library)

  @english_chants Enum.map(english["chants"], &{&1["id"], &1["setting"]})
  @group_ids Enum.map(english["groups"], & &1["id"])

  # Each group's parts as the English has them: `{has title?, has note?}`
  # by position, so a Spanish part says exactly what its English says.
  @english_parts Map.new(english["groups"], fn group ->
                   {group["id"],
                    Enum.map(
                      group["parts"] || [],
                      &{is_binary(&1["title"]), is_binary(&1["note"])}
                    )}
                 end)

  @english_group_notes Map.new(english["groups"], &{&1["id"], is_binary(&1["note"])})

  @chants Map.get(file, "chants", %{})
  @groups Map.get(file, "groups", %{})

  fail = fn message ->
    raise CompileError, description: "priv/library/es/chant_library.json: " <> message
  end

  words? = &(is_binary(&1) and String.trim(&1) != "")

  for {id, chant} <- @chants do
    case List.keyfind(@english_chants, id, 0) do
      nil ->
        fail.("chants holds #{inspect(id)}, which the library does not have")

      {^id, english_setting} ->
        words?.(chant["title"]) || fail.("the chant #{id} needs a title")

        cond do
          Map.keys(chant) -- ["title", "setting"] != [] ->
            fail.("the chant #{id} holds only a title and a setting")

          is_nil(english_setting) and Map.has_key?(chant, "setting") ->
            fail.("the chant #{id} has no setting in English, so none in Spanish")

          is_binary(english_setting) and not words?.(chant["setting"]) ->
            fail.("the chant #{id} needs a setting, as its English has one")

          true ->
            :ok
        end
    end
  end

  for {id, group} <- @groups do
    id in @group_ids || fail.("groups holds #{inspect(id)}, which the library does not have")

    words?.(group["title"]) || fail.("the group #{id} needs a title")

    Map.keys(group) -- ["title", "note", "parts"] == [] ||
      fail.("the group #{id} holds only a title, a note and its parts")

    case {@english_group_notes[id], Map.has_key?(group, "note")} do
      {true, true} -> words?.(group["note"]) || fail.("the group #{id}'s note is empty")
      {false, true} -> fail.("the group #{id} has no note in English, so none in Spanish")
      _ -> :ok
    end

    with parts when is_list(parts) <- group["parts"] do
      english_parts = @english_parts[id]

      length(parts) == length(english_parts) ||
        fail.("the group #{id} has #{length(english_parts)} parts, so its parts list has as many")

      for {{part, {title?, note?}}, index} <- Enum.with_index(Enum.zip(parts, english_parts)) do
        (Map.has_key?(part, "title") == title? and Map.has_key?(part, "note") == note? and
           Enum.all?(Map.values(part), words?)) ||
          fail.(
            "the group #{id}'s part #{index} holds a title and a note exactly where its English does"
          )
      end
    end
  end

  @doc """
  The Spanish, as the `translations` section serves it: `chants`, each
  `%{id:, title:, setting:}` (`setting` nil where the English has none),
  and `groups`, each `%{id:, title:, note:, parts:}` (`note` nil where the
  English has none; `parts` the group's parts in the English order, each
  `%{title:, note:}`, or empty where the group's parts have no words),
  listing only those with Spanish, in the English sections' order.
  """
  @spec translation() :: %{chants: [map], groups: [map]}
  def translation do
    %{
      chants:
        for(
          {id, _setting} <- @english_chants,
          chant = @chants[id],
          do: %{id: id, title: chant["title"], setting: chant["setting"]}
        ),
      groups:
        for(
          id <- @group_ids,
          group = @groups[id],
          do: %{
            id: id,
            title: group["title"],
            note: group["note"],
            parts:
              for(part <- group["parts"] || [], do: %{title: part["title"], note: part["note"]})
          }
        )
    }
  end

  @doc "When `priv/library/es/chant_library.json` last changed."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version, do: Content.version(%{"chants" => @chants, "groups" => @groups})
end
