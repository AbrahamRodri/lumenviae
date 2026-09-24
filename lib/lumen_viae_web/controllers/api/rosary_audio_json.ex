defmodule LumenViaeWeb.API.RosaryAudioJSON do
  @doc """
  Renders one voice's spoken-Rosary manifest.

  Grouped the way the app looks clips up while it prays: prayers by prayer
  id, announcements by `"<category>_<order>"`, verses by the same key as
  a list in bead order, and the Prayer Book's prayers (`book`) by the
  book's prayer ids. A kind left out by `include` is absent rather
  than empty, so an empty map always means "nothing recorded", never
  "not asked for".
  """
  def show(%{voice: voice, version: version, expires_at: expires_at, entries: entries}) do
    groups = Enum.group_by(entries, & &1.clip.kind)

    %{
      data:
        %{
          voice: voice.slug,
          version: version,
          expires_at: DateTime.to_iso8601(expires_at)
        }
        |> put_group(groups, :prayer, :prayers, fn items ->
          Map.new(items, &{&1.clip.name, file(&1)})
        end)
        |> put_group(groups, :announcement, :announcements, fn items ->
          Map.new(items, &{&1.clip.mystery, Map.put(file(&1), :text, &1.clip.text)})
        end)
        |> put_group(groups, :verse, :verses, fn items ->
          items
          |> Enum.group_by(& &1.clip.mystery)
          |> Map.new(fn {mystery, beads} ->
            {mystery,
             beads
             |> Enum.sort_by(& &1.clip.bead)
             |> Enum.map(&Map.put(file(&1), :reference, &1.clip.reference))}
          end)
        end)
        |> put_group(groups, :book, :book, fn items ->
          Map.new(items, &{&1.clip.name, file(&1)})
        end)
    }
  end

  defp put_group(data, groups, kind, field, render) do
    case Map.fetch(groups, kind) do
      {:ok, items} -> Map.put(data, field, render.(items))
      :error -> data
    end
  end

  defp file(entry), do: %{file: entry.file, audio_url: entry.audio_url}
end
