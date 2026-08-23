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
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Dashboard Set #{System.unique_integer([:positive])}", category: "joyful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(%{
        name: "Dashboard Mystery #{System.unique_integer([:positive])}",
        category: "joyful",
        order: System.unique_integer([:positive])
      })

    mystery
  end

  defp create_meditation(mystery, attrs \\ %{}) do
    defaults = %{content: "Meditation content", mystery_id: mystery.id}
    {:ok, meditation} = Rosary.create_meditation(Map.merge(defaults, attrs))
    meditation
  end

  defp add_artwork(set) do
    {:ok, set} =
      Rosary.update_meditation_set_artwork(set, %{
        "image_key" => "sets/#{set.id}/painting.jpg",
        "image_width" => 1600,
        "image_height" => 2400
      })

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
      hidden = create_set()
      meditation = create_meditation(mystery, %{audio_url: "a.mp3"})
      {:ok, _} = Rosary.add_meditation_to_set(hidden.id, meditation.id, 1)

      {:ok, _view, html} = live(conn, "/admin")
      assert health_count(html, "Live sets without artwork") == "1"

      {:ok, _} = Rosary.archive_meditation(meditation)

      {:ok, _view, html} = live(conn, "/admin")
      assert health_count(html, "Live sets without artwork") == nil
      assert health_count(html, "Sets hidden from the public") == "1"
    end
  end

  describe "narration" do
    test "counts only meditations a live set can reach", %{conn: conn} do
      mystery = create_mystery()
      set = create_set() |> add_artwork()
      reachable = create_meditation(mystery)
      _orphan = create_meditation(mystery)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, reachable.id, 1)

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
      assert Rosary.completion_summary().last_7 == 2
    end
  end
end
