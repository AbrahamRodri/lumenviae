defmodule LumenViae.Rosary.PaperTrailTest do
  @moduledoc """
  Every create, update and destroy of the four content resources leaves a
  version row holding the whole record, so an edit to a saint's verbatim
  text can always be seen and reversed.
  """
  use LumenViae.DataCase, async: true

  require Ash.Query

  alias LumenViae.Rosary

  defp versions_of(record) do
    record
    |> Ash.load!(:paper_trail_versions, actor: admin())
    |> Map.fetch!(:paper_trail_versions)
    |> Enum.sort_by(& &1.version_inserted_at, NaiveDateTime)
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    mystery
  end

  test "a meditation's text is kept at every step, and the action that changed it" do
    mystery = create_mystery()

    {:ok, meditation} =
      Rosary.create_meditation(%{content: "First wording.", mystery_id: mystery.id},
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.update_meditation(meditation, %{content: "Second wording."}, actor: admin())

    {:ok, meditation} = Rosary.archive_meditation(meditation, actor: admin())

    assert [created, edited, archived] = versions_of(meditation)

    assert created.version_action_type == :create
    assert created.version_action_name == :create
    assert created.changes["content"] == "First wording."
    assert created.changes["mystery_id"] == mystery.id

    assert edited.version_action_type == :update
    assert edited.version_action_name == :update
    assert edited.changes["content"] == "Second wording."

    assert archived.version_action_name == :archive
    assert archived.changes["archived_at"]
    # A snapshot, not a diff: the version holds the whole record.
    assert archived.changes["content"] == "Second wording."
  end

  test "each version records the admin who made it, and nobody for an operator's shell" do
    mystery = create_mystery()
    {:ok, _} = Rosary.update_mystery(mystery, %{name: "Renamed"}, authorize?: false)

    assert [by_admin, by_shell] = versions_of(mystery)
    assert by_admin.admin_id == admin().id
    assert by_shell.admin_id == nil
  end

  test "nothing is written for an update that changes nothing" do
    mystery = create_mystery()
    {:ok, _} = Rosary.update_mystery(mystery, %{name: mystery.name}, actor: admin())

    assert [%{version_action_type: :create}] = versions_of(mystery)
  end

  test "the timestamps are not in the snapshot" do
    mystery = create_mystery()

    assert [version] = versions_of(mystery)
    refute Map.has_key?(version.changes, "inserted_at")
    refute Map.has_key?(version.changes, "updated_at")
    assert version.changes["name"] == mystery.name
  end

  test "a destroyed record's last state survives in its versions" do
    {:ok, author} = Rosary.create_author(%{name: "St. Louis de Montfort"}, actor: admin())

    {:ok, author} =
      Rosary.update_author(author, %{name: "St. Louis-Marie de Montfort"}, actor: admin())

    {:ok, _} = Rosary.delete_author(author, actor: admin())

    versions =
      LumenViae.Rosary.Author.Version
      |> Ash.Query.filter(version_source_id == ^author.id)
      |> Ash.Query.sort(version_inserted_at: :asc)
      |> Ash.read!(actor: admin())

    assert [%{version_action_type: :create}, %{version_action_type: :update}, destroyed] =
             versions

    assert destroyed.version_action_type == :destroy
    assert destroyed.changes["name"] == "St. Louis-Marie de Montfort"
  end

  test "a set's artwork and labels are versioned through their own actions" do
    {:ok, set} = Rosary.create_meditation_set(%{name: "Set", category: "joyful"}, actor: admin())
    {:ok, set} = Rosary.update_meditation_set(set, %{labels: ["Saints"]}, actor: admin())

    {:ok, set} =
      Rosary.update_meditation_set_artwork(
        set,
        %{
          "image_key" => "sets/#{set.id}/a.jpg",
          "image_width" => 1600,
          "image_height" => 2400
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.update_meditation_set_artwork_metadata(set, %{"image_focal_y" => 0.24},
        actor: admin()
      )

    names = set |> versions_of() |> Enum.map(& &1.version_action_name)
    assert names == [:create, :update, :record_artwork, :update_artwork_metadata]

    assert List.last(versions_of(set)).changes["image_focal_y"] == 0.24
    assert List.last(versions_of(set)).changes["labels"] == ["Saints"]
  end

  test "the versions are the domain's, with no GraphQL type and no public relationship" do
    for version <- [
          LumenViae.Rosary.Mystery.Version,
          LumenViae.Rosary.Meditation.Version,
          LumenViae.Rosary.MeditationSet.Version,
          LumenViae.Rosary.Author.Version
        ] do
      assert version in Ash.Domain.Info.resources(Rosary)
      refute AshGraphql.Resource in Spark.extensions(version)
    end

    for resource <- [
          LumenViae.Rosary.Mystery,
          LumenViae.Rosary.Meditation,
          LumenViae.Rosary.MeditationSet,
          LumenViae.Rosary.Author
        ] do
      refute Ash.Resource.Info.relationship(resource, :paper_trail_versions).public?
    end
  end
end
