defmodule LumenViae.AshOpts do
  @moduledoc """
  The options a caller passes on to Ash: who is asking (`actor:`), or, for
  an operator's shell, `authorize?: false`.

  `LumenViae.Rosary` and the curation services take one keyword list that
  mixes these with options of their own (`:dry_run`, `:voices`,
  `:on_progress`). A code interface validates its options and refuses keys
  it does not know, so only these two are handed on.
  """

  @doc "Keeps only `:actor` and `:authorize?`."
  def take(opts), do: Keyword.take(opts, [:actor, :authorize?])
end
