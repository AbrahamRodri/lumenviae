defmodule LumenViae.Ops.ErrorLineTest do
  use ExUnit.Case, async: true

  alias LumenViae.Ops.ErrorLine

  test "a plain message is its first line" do
    assert ErrorLine.summary("connection refused\nstack") == "connection refused"
  end

  test "an Ash error is its first cause, not the blank line or the header" do
    message =
      "\nBread Crumbs:\n  > Error returned from: X.create\n\nInvalid Error\n\n* attribute name is required\n  (ash 3.37.2) lib/ash.ex:8\n* another"

    assert ErrorLine.summary(message) == "attribute name is required"
  end

  test "cuts a long line, and an empty message is empty" do
    assert ErrorLine.summary(String.duplicate("a", 300), 10) == "aaaaaaaaaa"
    assert ErrorLine.summary("\n\n") == ""
  end
end
