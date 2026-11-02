defmodule LumenViae.Rosary.RosaryContent.SpanishNamesTest do
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.RosaryContent.SpanishNames

  # priv/rosary_content/es/mysteries.json, each {updated_at, version} it has
  # been served at, oldest first. Change a word: bump the file's updated_at
  # and add the new pair at the end.
  @history [
    {~U[2026-11-03 00:00:00Z], "b0ed7117b22bd8b1"},
    {~U[2026-11-03 00:10:00Z], "e5625f395a38d398"}
  ]

  test "the file is dated and versioned as its history last records it" do
    {pinned_at, pinned_version} = List.last(@history)

    assert {SpanishNames.updated_at(), SpanishNames.version()} == {pinned_at, pinned_version}, """
    priv/rosary_content/es/mysteries.json changed (now #{SpanishNames.version()}).
    Bump its updated_at and add {~U[...], "#{SpanishNames.version()}"} to @history here.
    """
  end

  test "every mystery the app knows has a Spanish name and fruit" do
    for key <- Categories.mystery_keys() do
      assert %{name: name, fruit: fruit} = SpanishNames.mystery(key), key
      assert String.trim(name) != "" and String.trim(fruit) != "", key
    end
  end

  test "every set has a Spanish name and devotion title" do
    for slug <- Categories.slugs() do
      assert %{name: name, devotion_title: title} = SpanishNames.category(slug), slug
      assert String.trim(name) != "" and String.trim(title) != "", slug
    end

    assert SpanishNames.category("seven_sorrows") == %{
             name: "Siete Dolores",
             devotion_title: "Los siete dolores de María"
           }
  end

  test "an unknown key has no Spanish" do
    assert SpanishNames.mystery("joyful_9") == nil
    assert SpanishNames.category("nope") == nil
  end
end
