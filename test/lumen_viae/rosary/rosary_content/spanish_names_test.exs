defmodule LumenViae.Rosary.RosaryContent.SpanishNamesTest do
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.RosaryContent.SpanishNames

  # priv/rosary_content/es/mysteries.json, each {updated_at, version} it has
  # been served at, oldest first. Change a word: bump the file's updated_at
  # and add the new pair at the end.
  @history [
    {~U[2026-11-03 00:00:00Z], "b0ed7117b22bd8b1"}
  ]

  # The Seven Sorrows set keeps its English names: the file names the four
  # sets of the Rosary only.
  @spanish_sets ~w(joyful luminous sorrowful glorious)

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

  test "the four sets of the Rosary have Spanish names, and nothing else does" do
    for slug <- Categories.slugs() do
      if slug in @spanish_sets do
        assert %{name: _, devotion_title: "Misterios " <> _} = SpanishNames.category(slug)
      else
        assert SpanishNames.category(slug) == nil
      end
    end
  end

  test "an unknown key has no Spanish" do
    assert SpanishNames.mystery("joyful_9") == nil
    assert SpanishNames.category("nope") == nil
  end
end
