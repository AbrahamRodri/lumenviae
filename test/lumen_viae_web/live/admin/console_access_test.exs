defmodule LumenViaeWeb.Live.Admin.ConsoleAccessTest do
  @moduledoc """
  The console cannot be reached without a signed-in admin, by any route.

  `LumenViaeWeb.Plugs.RequireAdmin` guards the HTTP request, but a LiveView
  can also be reached by live navigation, which mounts the next page over
  the open websocket and runs no plug. These tests take that route as an
  attacker would: open a public page, then navigate into the console.
  Before the console had its own live_session, that mounted it.
  """
  use LumenViaeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LumenViae.Test.EnvStub, only: [put_env: 3]

  setup do
    # The suite is never configured to skip the login, but say so: these
    # tests are about the guard, and dev's skip flag would disarm it.
    put_env(:lumen_viae, :skip_admin_auth, false)
    :ok
  end

  defp console_routes do
    LumenViaeWeb.Router.__routes__()
    |> Enum.filter(fn route ->
      String.starts_with?(route.path, "/admin") and route.path != "/admin/login" and
        route.plug == Phoenix.LiveView.Plug
    end)
  end

  defp live_session_of(path) do
    sample = path |> String.replace(":id", "1") |> String.replace("/*route", "")
    info = Phoenix.Router.route_info(LumenViaeWeb.Router, "GET", sample, "localhost")
    {_view, _action, _opts, live_session} = info.phoenix_live_view
    live_session
  end

  # AshAdmin's pages and Oban Web's live in live_sessions of their own
  # (:ash_admin, :oban_jobs), which still keeps them apart from the site;
  # what matters is the hook.
  test "every console page sits in a console live_session, behind the admin hook" do
    routes = console_routes()
    assert length(routes) >= 10, "expected the console's LiveViews, found #{length(routes)}"
    assert Enum.any?(routes, &String.starts_with?(&1.path, "/admin/data"))

    for route <- routes do
      live_session = live_session_of(route.path)

      assert live_session.name in [:admin, :ash_admin, :oban_jobs],
             "#{route.path} is in live_session #{inspect(live_session.name)}, not a console one"

      assert Enum.any?(
               live_session.extra.on_mount,
               &match?(%{id: {LumenViaeWeb.UserAuth, :require_admin}}, &1)
             ),
             "#{route.path} does not run UserAuth :require_admin on mount"
    end
  end

  test "live navigation from a public page into the console is forced through HTTP",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert {:error, {:redirect, %{to: to}}} = live_redirect(view, to: "/admin/meditations")
    assert URI.parse(to).path == "/admin/meditations"

    # And that HTTP request is the one the plug turns away.
    assert redirected_to(get(conn, "/admin/meditations")) == "/admin/login"
  end

  test "AshAdmin is behind the same guard", %{conn: conn} do
    assert redirected_to(get(conn, "/admin/data")) == "/admin/login"

    {:ok, view, _html} = live(conn, "/")
    assert {:error, {:redirect, %{to: to}}} = live_redirect(view, to: "/admin/data")
    assert URI.parse(to).path == "/admin/data"

    signed_in = log_in_admin(conn)
    assert {:ok, _view, html} = live(signed_in, "/admin/data")
    assert html =~ "Rosary"
  end

  # AshAdmin runs every action with authorize?: false once its sidebar says
  # "Auth bypassed", which would let a signed-in admin make admins from the
  # browser. The sidebar hides the button here (no actor resources), but a
  # client can still send the event over the socket, so both ways of
  # reaching that state are dropped. Read from the LiveView's own state,
  # since nothing on the page shows it.
  test "AshAdmin's authorization cannot be switched off", %{conn: conn} do
    admin = admin_fixture()
    {:ok, view, _html} = live(log_in_admin(conn, admin), "/admin/data")

    for event <- ["toggle_authorizing", "clear_actor"] do
      render_click(view, event, %{})
      assigns = :sys.get_state(view.pid).socket.assigns

      assert assigns.authorizing, "#{event} switched authorization off"
      assert assigns.actor.id == admin.id, "#{event} changed the actor"
    end
  end

  # Only the refusal: the dashboard itself cannot render under Oban's
  # manual test mode, which starts none of the processes it reports on.
  test "Oban Web is behind the same guard", %{conn: conn} do
    assert redirected_to(get(conn, "/admin/jobs")) == "/admin/login"

    {:ok, view, _html} = live(conn, "/")
    assert {:error, {:redirect, %{to: to}}} = live_redirect(view, to: "/admin/jobs")
    assert URI.parse(to).path == "/admin/jobs"
  end

  test "live navigation from the login page into the console is forced through HTTP",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/login")

    assert {:error, {:redirect, %{to: to}}} = live_redirect(view, to: "/admin")
    assert URI.parse(to).path == "/admin"
  end

  test "a signed-in admin still navigates within the console in place", %{conn: conn} do
    conn = log_in_admin(conn)

    {:ok, view, _html} = live(conn, "/admin")

    assert {:ok, _view, html} = live_redirect(view, to: "/admin/meditations")
    assert html =~ "Meditations"
  end

  defp socket do
    %Phoenix.LiveView.Socket{
      endpoint: LumenViaeWeb.Endpoint,
      assigns: %{__changed__: %{}, flash: %{}}
    }
  end

  test "the admin hook refuses a socket without a signed-in admin" do
    assert {:halt, halted} = LumenViaeWeb.UserAuth.on_mount(:require_admin, %{}, %{}, socket())
    assert {:redirect, %{to: "/admin/login"}} = halted.redirected
  end

  test "the old shared-password session flag no longer opens the console" do
    session = %{"admin_authenticated" => true}

    assert {:halt, _halted} =
             LumenViaeWeb.UserAuth.on_mount(:require_admin, %{}, session, socket())
  end

  test "the admin hook admits a signed-in admin and makes them the actor", %{conn: conn} do
    admin = admin_fixture()
    session = conn |> log_in_admin(admin) |> get_session()

    assert {:cont, allowed} =
             LumenViaeWeb.UserAuth.on_mount(:require_admin, %{}, session, socket())

    assert allowed.assigns.is_admin
    assert allowed.assigns.current_admin.id == admin.id
  end

  test "a session whose token was revoked by signing out is refused", %{conn: conn} do
    signed_in = log_in_admin(conn)
    session = get_session(signed_in)

    signed_out = delete(signed_in, "/admin/session")
    assert redirected_to(signed_out) == "/"

    assert {:halt, _halted} =
             LumenViaeWeb.UserAuth.on_mount(:require_admin, %{}, session, socket())
  end
end
