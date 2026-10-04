defmodule LumenViaeWeb.Live.Admin.HistoryTest do
  @moduledoc """
  The History panel on the console's edit pages: what each change did, who
  made it, and putting an earlier version back.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary
  alias LumenViaeWeb.Components.History

  setup %{conn: conn} do
    admin = admin_fixture()
    {:ok, conn: log_in_admin(conn, admin), admin: admin}
  end

  defp create_mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "The Visitation",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    mystery
  end

  test "an edit shows who made it and what changed, and Restore puts it back", %{
    conn: conn,
    admin: admin
  } do
    mystery = create_mystery()
    {:ok, view, _html} = live(conn, "/admin/mysteries/#{mystery.id}/edit")

    html =
      view
      |> form("form[phx-submit=update_mystery]", %{mystery: %{name: "The Visitation of Mary"}})
      |> render_submit()

    assert html =~ to_string(admin.email)
    assert html =~ "The Visitation of Mary"

    [_current, created] = Rosary.list_history(mystery, actor: admin())

    html =
      view
      |> element(~s(button[phx-click=restore_version][phx-value-id="#{created.id}"]))
      |> render_click()

    assert html =~ "Version restored"
    assert Rosary.get_mystery!(mystery.id, actor: admin()).name == "The Visitation"

    assert [%{action: :update}, %{action: :update}, %{action: :create}] =
             Rosary.list_history(mystery, actor: admin())
  end

  test "a version of another record is not restored" do
    mystery = create_mystery()
    other = create_mystery()
    [other_version] = Rosary.list_history(other, actor: admin())

    assert {:error, _} = Rosary.restore_version(mystery, other_version.id, actor: admin())
  end

  test "only an admin may read a record's history: the public is shown none" do
    mystery = create_mystery()
    assert [_created] = Rosary.list_history(mystery, actor: admin())
    assert Rosary.list_history(mystery) == []
  end

  describe "the panel's diff" do
    test "a long text changed by one word reads as that word" do
      old = String.duplicate("Hail Mary full of grace ", 5) <> "the Lord is with thee."
      new = String.replace(old, "thee.", "you.")

      assert [{:eq, _}, {:del, "thee."}, {:ins, "you."}] = History.word_diff(old, new)
    end

    test "each entry lists the fields that differ from the version before it" do
      history = [
        %{
          id: 2,
          type: :update,
          action: :update,
          snapshot: %{"id" => 1, "name" => "B", "order" => 1}
        },
        %{
          id: 1,
          type: :create,
          action: :create,
          snapshot: %{"id" => 1, "name" => "A", "order" => 1}
        }
      ]

      assert [updated, created] = History.entries(history)
      assert updated.diff == [%{field: "name", before: "A", after: "B"}]
      assert Enum.map(created.diff, & &1.field) == ["name", "order"]
    end

    test "an update with nothing before it on record says so rather than listing every field" do
      history = [%{id: 1, type: :update, action: :update, snapshot: %{"name" => "A"}}]
      assert [%{diff: :unrecorded}] = History.entries(history)
    end
  end
end
