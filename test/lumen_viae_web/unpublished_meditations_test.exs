defmodule LumenViaeWeb.UnpublishedMeditationsTest do
  @moduledoc """
  A6, decided 4 Oct 2026: a meditation in no set at all is a draft, and no
  public surface reads it or signs its audio. Each surface answers a draft
  exactly as it answers an id that does not exist, so a draft's existence
  is not given away.

  A meditation in a set that is hidden stays readable on purpose: the app
  keeps praying a set saved on the device after it is hidden, and asks
  `GET /api/meditations/:id/audio` for fresh links to its narration
  (docs/IOS_API_CONTRACT.md, section 3). A meditation in a visible set is
  unchanged.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViae.Test.EnvStub, only: [put_env: 1]
  import LumenViaeWeb.GraphqlHelpers
  import LumenViaeWeb.JsonApiHelpers

  alias LumenViae.Rosary

  @missing_id 987_654_321

  setup do
    put_env([
      {:ex_aws, :access_key_id, "test-key"},
      {:ex_aws, :secret_access_key, "test-secret"}
    ])

    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "A6 Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    narrated = fn content, file ->
      {:ok, meditation} =
        Rosary.create_meditation(%{content: content, mystery_id: mystery.id}, actor: admin())

      {:ok, _} =
        Rosary.record_narration(meditation, "female", "voices/female/#{file}", actor: admin())

      meditation
    end

    set = fn ->
      {:ok, set} =
        Rosary.create_meditation_set(
          %{name: "A6 Set #{System.unique_integer([:positive])}", category: "joyful"},
          actor: admin()
        )

      set
    end

    draft = narrated.("Not in any set yet.", "draft.mp3")

    visible = narrated.("In a visible set.", "visible.mp3")
    visible_set = set.()
    {:ok, _} = Rosary.add_meditation_to_set(visible_set.id, visible.id, 1, actor: admin())

    # Hidden the way sets are hidden in practice: another meditation in it
    # was archived.
    in_hidden = narrated.("In a set hidden since.", "hidden.mp3")
    withdrawn = narrated.("Archived.", "withdrawn.mp3")
    hidden_set = set.()
    {:ok, _} = Rosary.add_meditation_to_set(hidden_set.id, in_hidden.id, 1, actor: admin())
    {:ok, _} = Rosary.add_meditation_to_set(hidden_set.id, withdrawn.id, 2, actor: admin())
    {:ok, _} = Rosary.archive_meditation(withdrawn, actor: admin())

    %{draft: draft, visible: visible, in_hidden: in_hidden}
  end

  describe "GET /api/meditations/:id/audio" do
    test "a draft answers exactly as a meditation that does not exist", %{
      conn: conn,
      draft: draft
    } do
      missing = conn |> get(~p"/api/meditations/#{@missing_id}/audio") |> json_response(404)
      answer = conn |> get(~p"/api/meditations/#{draft.id}/audio") |> json_response(404)

      assert answer == missing
    end

    test "a meditation in a hidden set is still signed, so a saved set keeps its narration", %{
      conn: conn,
      in_hidden: in_hidden
    } do
      %{"data" => data} =
        conn |> get(~p"/api/meditations/#{in_hidden.id}/audio") |> json_response(200)

      assert data["id"] == in_hidden.id
      assert URI.parse(data["audio_url"]).path == "/lumenviae-audio/voices/female/hidden.mp3"
    end

    test "a meditation in a visible set is unchanged", %{conn: conn, visible: visible} do
      %{"data" => data} =
        conn |> get(~p"/api/meditations/#{visible.id}/audio") |> json_response(200)

      assert URI.parse(data["audio_url"]).path == "/lumenviae-audio/voices/female/visible.mp3"
    end
  end

  describe "GraphQL meditationAudio" do
    @query """
    query Refresh($ids: [ID!]!) {
      meditationAudio(meditationIds: $ids) { meditationId voice }
    }
    """

    defp graphql_ids(conn, ids) do
      %{"data" => %{"meditationAudio" => answers}} =
        graphql(conn, @query, %{ids: Enum.map(ids, &to_string/1)})

      Enum.map(answers, & &1["meditationId"])
    end

    test "leaves a draft out, as it leaves out an id that does not exist", %{
      conn: conn,
      draft: draft,
      visible: visible,
      in_hidden: in_hidden
    } do
      assert graphql_ids(conn, [draft.id]) == graphql_ids(conn, [@missing_id])
      assert graphql_ids(conn, [draft.id]) == []

      assert graphql_ids(conn, [draft.id, in_hidden.id, visible.id]) ==
               [to_string(in_hidden.id), to_string(visible.id)]
    end
  end

  describe "POST /api/v2/meditations/audio" do
    defp v2_ids(conn, ids) do
      conn
      |> post_v2("/meditations/audio", %{data: %{meditation_ids: ids}})
      |> v2_response(201)
      |> Enum.map(& &1["meditation_id"])
    end

    test "signs no draft, and signs a meditation in a hidden set", %{
      conn: conn,
      draft: draft,
      visible: visible,
      in_hidden: in_hidden
    } do
      assert v2_ids(conn, [draft.id]) == v2_ids(conn, [@missing_id])
      assert v2_ids(conn, [draft.id]) == []
      assert v2_ids(conn, [draft.id, in_hidden.id, visible.id]) == [in_hidden.id, visible.id]
    end
  end

  describe "the domain" do
    test "the public cannot read a draft; the console and system writes can", %{draft: draft} do
      assert {:error, _not_found} = Rosary.get_meditation(draft.id)
      assert {:ok, _} = Rosary.get_meditation(draft.id, actor: admin())

      # NarrateMeditation reads this way, so a fresh import's narration,
      # recorded before its row joins a set, is unaffected.
      assert {:ok, _} = Rosary.get_meditation(draft.id, authorize?: false)
    end
  end
end
