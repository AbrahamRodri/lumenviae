defmodule LumenViae.Rosary.SetSummariesTest do
  @moduledoc """
  `Rosary.list_visible_meditation_set_summaries!/0` and its by-category
  sibling are for pages that list sets and say how many meditations each
  has and whether any is narrated. They answer in the query, so the text of
  every meditation stays in the database.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Test.Sets

  defp visible_set(name, category, meditation_attrs_list) do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: name, category: category}, actor: admin())

    Enum.reduce(meditation_attrs_list, set, fn attrs, set -> Sets.with_meditation(set, attrs) end)
  end

  test "count a set's meditations and its narrated ones, without loading them" do
    name = "Summary #{System.unique_integer([:positive])}"

    set =
      visible_set(name, "joyful", [
        %{audio_url: "one.mp3"},
        %{audio_url: nil},
        %{audio_url: "three.mp3"}
      ])

    summary = Enum.find(Rosary.list_visible_meditation_set_summaries!(), &(&1.id == set.id))

    assert summary.meditation_count == 3
    assert summary.audio_count == 2
    refute is_list(summary.meditations)
    assert %Ash.NotLoaded{} = summary.meditations
  end

  test "a set with no narration has an audio count of zero" do
    set = visible_set("Silent #{System.unique_integer([:positive])}", "joyful", [%{}, %{}])

    summary = Enum.find(Rosary.list_visible_meditation_set_summaries!(), &(&1.id == set.id))

    assert summary.meditation_count == 2
    assert summary.audio_count == 0
  end

  test "an empty audio name is not narration" do
    set = visible_set("Blank #{System.unique_integer([:positive])}", "joyful", [%{audio_url: ""}])

    summary = Enum.find(Rosary.list_visible_meditation_set_summaries!(), &(&1.id == set.id))

    assert summary.audio_count == 0
  end

  test "still carry the author and byline the lists show" do
    set =
      visible_set("Byline #{System.unique_integer([:positive])}", "joyful", [
        %{author: "St. Bede"}
      ])

    summary = Enum.find(Rosary.list_visible_meditation_set_summaries!(), &(&1.id == set.id))

    assert summary.derived_author == "St. Bede"
  end

  test "by category, list only that category's visible sets" do
    joyful = visible_set("Only Joyful #{System.unique_integer([:positive])}", "joyful", [%{}])

    sorrowful =
      visible_set("Only Sorrowful #{System.unique_integer([:positive])}", "sorrowful", [%{}])

    {:ok, _hidden} =
      Rosary.create_meditation_set(
        %{name: "Hidden #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    ids =
      "joyful" |> Rosary.list_visible_meditation_set_summaries_by_category!() |> Enum.map(& &1.id)

    assert joyful.id in ids
    refute sorrowful.id in ids

    assert Enum.all?(
             Rosary.list_visible_meditation_set_summaries_by_category!("joyful"),
             &(&1.category == "joyful")
           )

    assert Enum.all?(
             Rosary.list_visible_meditation_set_summaries_by_category!("joyful"),
             &(&1.meditation_count > 0)
           )
  end
end
