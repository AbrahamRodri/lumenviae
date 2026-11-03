defmodule LumenViaeWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LumenViaeWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import ExUnit.Assertions, only: [assert: 2]

  using do
    quote do
      # The default endpoint for testing
      @endpoint LumenViaeWeb.Endpoint

      use LumenViaeWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import LumenViaeWeb.ConnCase
      import LumenViae.Test.Admins
    end
  end

  setup tags do
    LumenViae.DataCase.setup_sandbox(tags)

    # Pages that reach the Daily Missal (Home's Today's Mass, Hours of
    # Prayer's day) fetch it once connected. No test reaches Missale Meum:
    # it answers as down unless a test stubs it, and each test's Office
    # cache is its own, so a failure one test holds never reaches another.
    LumenViae.Office.Cache.isolate()
    Req.Test.stub(LumenViae.Office.MissaleMeum, &Req.Test.transport_error(&1, :econnrefused))

    # The same for the Spiritual Reading recordings' track lists from
    # LibriVox: down unless a test stubs it, held apart per test.
    LumenViae.Rosary.SpiritualReading.Recording.isolate()

    Req.Test.stub(
      LumenViae.Rosary.SpiritualReading.LibriVox,
      &Req.Test.transport_error(&1, :econnrefused)
    )

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  # The iOS app decodes optional fields as Swift Optionals: null is fine,
  # any other type fails the whole response. These say "a T or null".
  def assert_string_or_nil(value, label) do
    assert is_nil(value) or is_binary(value),
           "#{label} must be a string or null: #{inspect(value)}"
  end

  def assert_integer_or_nil(value, label) do
    assert is_nil(value) or is_integer(value),
           "#{label} must be an integer or null: #{inspect(value)}"
  end

  def assert_number_or_nil(value, label) do
    assert is_nil(value) or is_number(value),
           "#{label} must be a number or null: #{inspect(value)}"
  end

  # ISO8601DateFormatter() with its defaults, which is what the app parses
  # these with, rejects fractional seconds and any offset but Z.
  def assert_utc_second(value, label) do
    assert is_binary(value) and value =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/,
           "#{label} must be YYYY-MM-DDTHH:MM:SSZ: #{inspect(value)}"
  end
end
