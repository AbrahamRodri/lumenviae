defmodule LumenViaeWeb.Live.Mysteries.AdminTest do
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_mystery(attrs \\ %{}) do
    defaults = %{name: "The Annunciation", category: "joyful", order: 1}
    {:ok, mystery} = Rosary.create_mystery(Map.merge(defaults, attrs))
    mystery
  end

  describe "new" do
    test "creates a mystery and moves on to its edit page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/mysteries/new")

      view
      |> form("form[phx-submit=create_mystery]", %{
        mystery: %{
          name: "The Visitation",
          category: "joyful",
          order: "2",
          scripture_reference: "Luke 1:39-56"
        }
      })
      |> render_submit()

      assert [mystery] = Rosary.list_mysteries!()
      assert mystery.name == "The Visitation"
      assert mystery.order == 2
      assert mystery.scripture_reference == "Luke 1:39-56"

      assert_redirect(view, "/admin/mysteries/#{mystery.id}/edit")
    end

    test "keeps what was typed and shows the error beside the field", %{conn: conn} do
      create_mystery()
      {:ok, view, _html} = live(conn, "/admin/mysteries/new")

      html =
        view
        |> form("form[phx-submit=create_mystery]", %{
          mystery: %{name: "A second first mystery", category: "joyful", order: "1"}
        })
        |> render_submit()

      assert html =~ "Failed to create mystery"
      assert html =~ "has already been taken"
      assert html =~ ~s(value="A second first mystery")
      assert length(Rosary.list_mysteries!()) == 1
    end
  end

  describe "edit" do
    test "shows the saved values and saves a change", %{conn: conn} do
      mystery = create_mystery(%{description: "The angel Gabriel is sent to Mary."})
      {:ok, view, html} = live(conn, "/admin/mysteries/#{mystery.id}/edit")

      assert html =~ ~s(value="The Annunciation")
      assert html =~ "The angel Gabriel is sent to Mary."

      html =
        view
        |> form("form[phx-submit=update_mystery]", %{
          mystery: %{days_prayed: "Monday, Saturday"}
        })
        |> render_submit()

      assert html =~ "Mystery updated successfully"
      assert Rosary.get_mystery!(mystery.id).days_prayed == "Monday, Saturday"
    end

    test "a second save after the first still works on the current row", %{conn: conn} do
      mystery = create_mystery()
      {:ok, view, _html} = live(conn, "/admin/mysteries/#{mystery.id}/edit")

      for name <- ["First rename", "Second rename"] do
        view
        |> form("form[phx-submit=update_mystery]", %{mystery: %{name: name}})
        |> render_submit()
      end

      assert Rosary.get_mystery!(mystery.id).name == "Second rename"
    end

    test "reports a clash with another mystery's position", %{conn: conn} do
      create_mystery()
      second = create_mystery(%{name: "The Visitation", order: 2})
      {:ok, view, _html} = live(conn, "/admin/mysteries/#{second.id}/edit")

      html =
        view
        |> form("form[phx-submit=update_mystery]", %{mystery: %{order: "1"}})
        |> render_submit()

      assert html =~ "Failed to update mystery"
      assert html =~ "has already been taken"
      assert Rosary.get_mystery!(second.id).order == 2
    end

    test "a mystery that does not exist is a 404", %{conn: conn} do
      error = assert_raise Ash.Error.Invalid, fn -> live(conn, "/admin/mysteries/0/edit") end

      assert Plug.Exception.status(error) == 404
    end
  end

  describe "list" do
    test "deletes a mystery with no meditations", %{conn: conn} do
      mystery = create_mystery()
      {:ok, view, _html} = live(conn, "/admin/mysteries")

      html = render_click(view, "delete_mystery", %{"id" => to_string(mystery.id)})

      assert html =~ "Mystery deleted successfully"
      assert Rosary.list_mysteries!() == []
    end

    test "says so, rather than crashing, when the mystery still has meditations", %{conn: conn} do
      mystery = create_mystery()
      {:ok, _} = Rosary.create_meditation(%{content: "Text.", mystery_id: mystery.id})
      {:ok, view, _html} = live(conn, "/admin/mysteries")

      html = render_click(view, "delete_mystery", %{"id" => to_string(mystery.id)})

      assert html =~ "Failed to delete mystery"
      assert [_still_there] = Rosary.list_mysteries!()
    end
  end
end
