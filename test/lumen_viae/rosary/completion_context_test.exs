defmodule LumenViae.Rosary.CompletionContextTest do
  @moduledoc """
  What a completion records about where it came from, and what it
  deliberately does not.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Repo
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Completions.Completion

  defp create_set do
    {:ok, set} =
      Rosary.create_meditation_set(%{
        name: "Ctx #{System.unique_integer([:positive])}",
        category: "joyful"
      })

    set
  end

  defp last_completion, do: Repo.one!(from c in Completion, order_by: [desc: c.id], limit: 1)

  describe "the context that is stored" do
    test "the surface, the timezone and the locale are kept as given" do
      set = create_set()

      {:ok, _} =
        Rosary.record_completion(set.id, %{
          source: "ios",
          time_zone: "America/Chicago",
          locale: "en-US"
        })

      completion = last_completion()

      assert completion.source == "ios"
      assert completion.time_zone == "America/Chicago"
      assert completion.locale == "en-US"
    end

    test "an empty context still records a completion" do
      set = create_set()

      assert {:ok, _} = Rosary.record_completion(set.id)

      completion = last_completion()

      assert completion.meditation_set_id == set.id
      assert completion.source == nil
      assert completion.ip_prefix == nil
    end

    test "a source that is not a surface we have is refused" do
      set = create_set()

      assert {:error, changeset} = Rosary.record_completion(set.id, %{source: "android"})
      assert "is invalid" in errors_on(changeset).source
    end
  end

  describe "the address" do
    test "is truncated before it is written down, never stored in full" do
      set = create_set()

      {:ok, _} = Rosary.record_completion(set.id, %{source: "web", ip: "203.0.113.77"})

      completion = last_completion()

      assert completion.ip_prefix == "203.0.113.0"
      refute completion.ip_prefix =~ "77"
    end

    test "an IPv6 address keeps only its routing prefix" do
      set = create_set()

      {:ok, _} = Rosary.record_completion(set.id, %{ip: "2001:db8:85a3:8d3:1319:8a2e:370:7348"})

      assert last_completion().ip_prefix == "2001:db8:85a3::"
    end

    test "nonsense in the address field is dropped rather than stored" do
      set = create_set()

      {:ok, _} = Rosary.record_completion(set.id, %{ip: "not an address"})

      assert last_completion().ip_prefix == nil
    end
  end

  describe "client-reported strings" do
    test "are bounded, because they arrive from a request body" do
      set = create_set()

      assert {:error, changeset} =
               Rosary.record_completion(set.id, %{time_zone: String.duplicate("x", 200)})

      assert errors_on(changeset).time_zone != []
    end
  end

  describe "completion_locations/1" do
    test "reports how much of the period actually has a place attached" do
      set = create_set()

      {:ok, _} = Rosary.record_completion(set.id, %{source: "web"})
      {:ok, _} = Rosary.record_completion(set.id, %{source: "ios"})

      locations = Rosary.completion_locations(30)

      # Nothing is placed: geolocation is off in test, so every row is
      # counted in the total and none in `located`. That gap is the number
      # the dashboard has to show rather than hide.
      assert locations.total == 2
      assert locations.located == 0
      assert locations.countries == []
      assert locations.sources == %{"web" => 1, "ios" => 1}
    end

    test "ranks the places that are known" do
      set = create_set()

      {:ok, a} = Rosary.record_completion(set.id, %{source: "web"})
      {:ok, b} = Rosary.record_completion(set.id, %{source: "web"})
      {:ok, c} = Rosary.record_completion(set.id, %{source: "ios"})

      # Stand in for the background lookup, which is what would normally
      # fill these in.
      place(a, %{city: "Dallas", region: "Texas", country: "United States", country_code: "US"})
      place(b, %{city: "Dallas", region: "Texas", country: "United States", country_code: "US"})

      place(c, %{
        city: "Manila",
        region: "Metro Manila",
        country: "Philippines",
        country_code: "PH"
      })

      locations = Rosary.completion_locations(30)

      assert locations.located == 3

      assert [%{country: "United States", count: 2}, %{country: "Philippines", count: 1}] =
               locations.countries

      assert [%{city: "Dallas", count: 2}, %{city: "Manila", count: 1}] = locations.cities
    end
  end

  defp place(completion, attrs) do
    completion
    |> Completion.changeset(attrs)
    |> Repo.update!()
  end
end
