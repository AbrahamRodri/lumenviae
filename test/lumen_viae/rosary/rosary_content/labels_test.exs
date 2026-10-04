defmodule LumenViae.Rosary.RosaryContent.LabelsTest do
  @moduledoc """
  The `labels` section of the content document, and how it dates and
  versions the document. The section is code, so it is pinned here as the
  content files' histories are in `content_test.exs`.
  """
  # The stamp reads the mysteries table, so the stamp tests need a connection.
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Labels
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Labels, as: LabelsSection

  # Each {updated_at, version} the section has been served at, oldest first.
  # Change the vocabulary, a display name or a kind: bump @updated_at in
  # RosaryContent.Labels and add the entry the test prints.
  @history [{~U[2026-10-04 02:40:00Z], "d3b2e11947a0d9a1"}]

  test "the section is dated and versioned as its history last records it" do
    {pinned_at, pinned_version} = List.last(@history)
    updated_at = LabelsSection.updated_at()
    version = LabelsSection.version()

    assert {updated_at, version} == {pinned_at, pinned_version}, """
    The labels section changed (now #{DateTime.to_iso8601(updated_at)}, #{version}).
    Bump @updated_at in LumenViae.Rosary.RosaryContent.Labels and add
      {~U[#{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M:%SZ")}], "#{version}"}
    to @history here.
    """
  end

  test "the history's dates increase and its version changes with each" do
    for [{at_a, version_a}, {at_b, version_b}] <- Enum.chunk_every(@history, 2, 1, :discard) do
      assert DateTime.compare(at_a, at_b) == :lt
      refute version_a == version_b
    end
  end

  test "names every label in the vocabulary, in its order" do
    section = LabelsSection.section()

    assert Enum.map(section["labels"], & &1["id"]) == Labels.vocabulary()
  end

  test "rewords only the three the app rewords, and leaves the rest as stored" do
    names = Map.new(LabelsSection.section()["labels"], &{&1["id"], &1["name"]})

    assert names["Considerations"] == "Reflections"
    assert names["Contemplative"] == "Inside the Scene"
    assert names["Scriptural"] == "Gospel"
    assert names["Saints"] == "Saints"
    assert names["Intentions"] == "Intentions"
    assert Labels.display_name("A label nobody stored") == "A label nobody stored"
  end

  test "a display name is only ever given to a label in the vocabulary" do
    assert Map.keys(Labels.display_names()) -- Labels.vocabulary() == []
  end

  test "the four kinds each explain a stored label, once" do
    kinds = LabelsSection.section()["kinds"]

    assert Enum.map(kinds, & &1["label"]) == ~w(Considerations Contemplative Saints Scriptural)
    assert Enum.all?(kinds, &(&1["label"] in Labels.vocabulary()))
    assert Enum.all?(kinds, &(&1["icon"] != "" and &1["title"] != "" and &1["description"] != ""))
  end

  describe "the document's stamp" do
    test "folds the section into the version" do
      assert "labels" in Current.folded_sections()
      refute Current.stamp(2026).version == Content.version()
    end

    test "is dated no earlier than the section" do
      assert DateTime.compare(Current.stamp(2026).updated_at, LabelsSection.updated_at()) in [
               :gt,
               :eq
             ]
    end
  end
end
