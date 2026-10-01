defmodule LumenViae.Rosary.CompletionRecordingTest do
  @moduledoc """
  The two ways a completion is recorded: `record_completion/2`, which the
  website and the REST API call and which says what surface it is, and the
  resource's `:record_from_app` action, which the public write API will
  call and which gets to say almost nothing.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completion

  defp create_set do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Recorded #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    set
  end

  defp hide(set) do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    {:ok, meditation} = Rosary.create_meditation(%{content: "Text.", mystery_id: mystery.id})
    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
    {:ok, _} = Rosary.archive_meditation(meditation)
    set
  end

  defp from_app(params, opts \\ []) do
    Completion
    |> Ash.Changeset.for_create(:record_from_app, params, opts)
    |> Ash.create()
  end

  describe "record_completion/2" do
    test "stamps the moment itself, to the second, in UTC" do
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, completion} = Rosary.record_completion(create_set().id)

      assert %DateTime{time_zone: "Etc/UTC", microsecond: {0, 0}} = completion.completed_at
      assert DateTime.compare(completion.completed_at, before) in [:gt, :eq]
      assert Rosary.count_total_completions() == 1
    end

    test "takes a string id, as a form or an older client might send one" do
      set = create_set()

      {:ok, completion} = Rosary.record_completion(to_string(set.id))

      assert completion.meditation_set_id == set.id
    end

    test "names the set when there is none, as the API's envelope prints it" do
      assert {:error, error} = Rosary.record_completion(999_999)
      assert Rosary.error_details(error) == %{meditation_set_id: ["does not exist"]}

      assert {:error, error} = Rosary.record_completion("not-an-id")
      assert Rosary.error_details(error) == %{meditation_set_id: ["is invalid"]}
    end

    # The REST API has always accepted a completion for a set the public can
    # no longer see: a set downloaded for offline prayer and hidden since
    # was still prayed. That stays.
    test "still records a completion for a hidden set" do
      set = create_set() |> hide()

      assert {:ok, completion} = Rosary.record_completion(set.id, %{source: "ios"})
      assert completion.meditation_set_id == set.id
    end

    # The row is written with no place, and the lookup that fills one in
    # only runs for a routable address with geolocation switched on, which
    # the test environment does not have. See completion_enrichment_test.
    test "writes the row placeless, with only the truncated prefix" do
      {:ok, completion} = Rosary.record_completion(create_set().id, %{ip: "203.0.113.99"})

      assert completion.ip_prefix == "203.0.113.0"
      assert completion.city == nil
      assert completion.country_code == nil
    end
  end

  describe "the app's own action" do
    test "records the set and whether it was prayed aloud, and nothing else is the client's to say" do
      set = create_set()

      {:ok, completion} =
        from_app(%{meditation_set_id: set.id, prayed_aloud: true},
          context: %{client_ip: "203.0.113.7"}
        )

      assert completion.meditation_set_id == set.id
      assert completion.prayed_aloud == true
      assert completion.source == "ios"
      assert completion.ip_prefix == "203.0.113.0"
      assert %DateTime{} = completion.completed_at
      assert completion.time_zone == nil
      assert completion.locale == nil
    end

    test "has no input for the surface, the address or the moment" do
      set = create_set()

      for extra <- [
            %{source: "web"},
            %{ip_prefix: "1.2.3.0"},
            %{completed_at: ~U[2020-01-01 00:00:00Z]},
            %{time_zone: "America/Chicago"}
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 from_app(Map.merge(%{meditation_set_id: set.id}, extra))
      end

      assert Rosary.count_total_completions() == 0
    end

    test "refuses a hidden set exactly as it refuses a missing one" do
      hidden = create_set() |> hide()

      assert {:error, hidden_error} = from_app(%{meditation_set_id: hidden.id})
      assert {:error, missing_error} = from_app(%{meditation_set_id: 999_999})

      assert Rosary.error_details(hidden_error) == %{meditation_set_id: ["does not exist"]}
      assert Rosary.error_details(missing_error) == %{meditation_set_id: ["does not exist"]}
      assert Rosary.count_total_completions() == 0
    end

    test "requires the set" do
      assert {:error, error} = from_app(%{prayed_aloud: false})
      assert %{meditation_set_id: [_message]} = Rosary.error_details(error)
    end
  end

  describe "readable fields" do
    test "are the id, the set and the moment, and nothing about where it came from" do
      public = Completion |> Ash.Resource.Info.public_attributes() |> Enum.map(& &1.name)

      assert Enum.sort(public) == [:completed_at, :id, :meditation_set_id]
    end
  end
end
