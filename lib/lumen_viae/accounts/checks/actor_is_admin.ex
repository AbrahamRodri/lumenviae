defmodule LumenViae.Accounts.Checks.ActorIsAdmin do
  @moduledoc """
  Passes when the actor is a signed-in console admin.

  Every resource's policies open with a bypass on this check, so an admin
  may do anything any action allows. A nil actor, or an actor of any other
  shape, does not pass: that is how a request from the public site, the
  REST API or GraphQL is told apart from the console.
  """
  use Ash.Policy.SimpleCheck

  alias LumenViae.Accounts.Admin

  @impl true
  def describe(_opts), do: "actor is a console admin"

  # Matched on `__struct__` rather than `%Admin{}`: a struct pattern needs
  # the Admin module compiled first, and Admin's own policies name this
  # check, so a clean build deadlocked between the two.
  @impl true
  def match?(%{__struct__: Admin}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
