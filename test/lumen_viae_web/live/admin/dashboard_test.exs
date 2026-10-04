defmodule LumenViaeWeb.Live.Admin.DashboardTest do
  @moduledoc """
  The dashboard's contract is that its health list reports on live content
  only, and that a healthy library shows nothing at all.

  That rule is easy to break by accident - every count added here is one
  more place to forget the hidden-set filter - so each health row that can
  be affected by visibility is tested from both sides.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  # A live set: it has a meditation. An empty set is hidden.
  defp create_set(attrs \\ %{}) do
    attrs |> create_empty_set() |> LumenViae.Test.Sets.with_meditation(%{audio_url: "set.mp3"})
  end

  # For a test that fills the set itself.
  defp create_empty_set(attrs \\ %{}) do
    defaults = %{name: "Dashboard Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs), actor: admin())
    set
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "Dashboard Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs), actor: admin())
    meditation
  end

  defp add_artwork(set) do
    {:ok, set} =
      Rosary.update_meditation_set_artwork(
        set,
        %{
          "image_key" => "sets/#{set.id}/painting.jpg",
          "image_width" => 1600,
          "image_height" => 2400
        },
        actor: admin()
      )

    set
  end

  # Each health row renders its count in a span beside the label, so read the
  # row containing the label and take the number out of it. Returns nil when
  # the row is absent, which is what a zero count looks like now.
  defp health_count(html, label) do
    {:ok, doc} = Floki.parse_document(html)

    doc
    |> Floki.find("li")
    |> Enum.find(&(Floki.text(&1) =~ label))
    |> case do
      nil -> nil
      row -> row |> Floki.find("span") |> Floki.text() |> String.trim()
    end
  end

  describe "sets without artwork" do
    test "counts the live sets still waiting for a painting", %{conn: conn} do
      create_set()
      create_set()

      {:ok, _view, html} = live(conn, "/admin")

      assert health_count(html, "Live sets without artwork") == "2"
    end

    test "the count drops as paintings are uploaded", %{conn: conn} do
      create_set()
      create_set() |> add_artwork()

      {:ok, _view, html} = live(conn, "/admin")

      assert health_count(html, "Live sets without artwork") == "1"
    end

    # A painting with no description is not served, so it is a different
    # problem from having no painting at all, and gets its own row.
    test "a painting with no description counts as not served, not as absent", %{conn: conn} do
      create_set() |> add_artwork()

      {:ok, _view, html} = live(conn, "/admin")

      assert health_count(html, "Live sets without artwork") == nil
      assert health_count(html, "Artwork uploaded but not served") == "1"
    end

    # The rule this whole screen turns on: a set nobody can reach is one
    # problem, listed once, under its own heading.
    test "a hidden set is not also counted as missing its artwork", %{conn: conn} do
      mystery = create_mystery()
      hidden = create_empty_set()
      meditation = create_meditation(mystery, %{audio_url: "a.mp3"})
      {:ok, _} = Rosary.add_meditation_to_set(hidden.id, meditation.id, 1, actor: admin())

      {:ok, _view, html} = live(conn, "/admin")
      assert health_count(html, "Live sets without artwork") == "1"

      {:ok, _} = Rosary.archive_meditation(meditation, actor: admin())

      {:ok, _view, html} = live(conn, "/admin")
      assert health_count(html, "Live sets without artwork") == nil
      assert health_count(html, "Sets hidden by an archived meditation") == "1"
    end

    # A set with no meditations yet is hidden for a different reason, and
    # says so under its own heading rather than being counted as withdrawn.
    test "an empty set is hidden, and listed under its own reason", %{conn: conn} do
      create_empty_set(%{name: "Just Created"})

      {:ok, _view, html} = live(conn, "/admin")

      assert health_count(html, "Sets with no meditations yet") == "1"
      assert health_count(html, "Sets hidden by an archived meditation") == nil
      assert health_count(html, "Live sets without artwork") == nil
      assert health_count(html, "Live sets without labels") == nil
      assert html =~ "/admin/meditation-sets?visibility=empty"
    end
  end

  describe "narration" do
    test "counts only meditations a live set can reach", %{conn: conn} do
      mystery = create_mystery()
      set = create_empty_set() |> add_artwork()
      reachable = create_meditation(mystery)
      _orphan = create_meditation(mystery)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, reachable.id, 1, actor: admin())

      {:ok, _view, html} = live(conn, "/admin")

      assert health_count(html, "Meditations without narration") == "1"
    end
  end

  describe "an empty checklist" do
    test "says so rather than listing rows that read zero", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin")

      assert html =~ "Nothing outstanding"
      refute html =~ "Live sets without artwork"
    end
  end

  describe "completion analytics" do
    test "reports the trailing windows and the sets behind them", %{conn: conn} do
      set = create_set(%{name: "Much Prayed Set"}) |> add_artwork()
      {:ok, _} = Rosary.record_completion(set.id)
      {:ok, _} = Rosary.record_completion(set.id)

      {:ok, _view, html} = live(conn, "/admin")

      assert html =~ "Much Prayed Set"
      assert html =~ "Rosaries completed"
      assert Rosary.completion_summary(actor: admin()).last_7 == 2
    end

    test "reads the website and each app apart", %{conn: conn} do
      set = create_set()

      for source <- ["web", "ios", "android", "android"] do
        {:ok, _} = Rosary.record_completion(set.id, %{source: source})
      end

      {:ok, _view, html} = live(conn, "/admin")
      {:ok, doc} = Floki.parse_document(html)

      rows =
        doc
        |> Floki.find("section")
        |> Enum.find(&(&1 |> Floki.find("h2") |> Floki.text() == "Website or app"))
        |> Floki.find("li")
        |> Enum.map(fn row ->
          [label, count] =
            row |> Floki.find(".truncate, span") |> Enum.map(&String.trim(Floki.text(&1)))

          {label, count}
        end)

      assert {"Android app", "2"} in rows
      assert {"iOS app", "1"} in rows
      assert {"Website", "1"} in rows
    end
  end

  describe "background jobs" do
    defp failed_job(state, queue) do
      LumenViae.Repo.insert!(%Oban.Job{
        worker: "LumenViae.Test.Worker",
        queue: queue,
        args: %{},
        state: state,
        attempt: 1,
        max_attempts: 3,
        errors: []
      })
    end

    test "a discarded job is a danger row, a retrying one a caution, each linked", %{conn: conn} do
      failed_job("discarded", "elevenlabs")
      failed_job("retryable", "geolocation")
      failed_job("retryable", "geolocation")

      {:ok, _view, html} = live(conn, "/admin")

      assert html =~ "Background jobs discarded"
      assert html =~ ~s(href="/admin/jobs/jobs?state=discarded")
      assert html =~ "Background jobs retrying"
      assert html =~ ~s(href="/admin/jobs/jobs?state=retryable")
    end

    test "completed and cancelled jobs are nobody's work", %{conn: conn} do
      failed_job("completed", "maintenance")
      failed_job("cancelled", "maintenance")

      {:ok, _view, html} = live(conn, "/admin")

      refute html =~ "Background jobs"
    end

    test "the dashboard links to the System screen", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin")
      assert html =~ ~s(href="/admin/system")
    end
  end
end
