defmodule LumenViae.Rosary.Completion.AppSource do
  @moduledoc """
  Sets which app a completion came from, on the user agent the server put
  in the action context (`:user_agent`, the one `Completion.NotAutomated`
  reads), never on anything the client named.

  `"android"` when the agent contains `Android`, in any case: the Android
  app identifies itself as
  `LumenViae-Android/<versionName> (Android <release>; <model>)`, and
  Android's own HTTP stack (`Dalvik/2.1.0 (Linux; U; Android 14; ...)`)
  says so too. Anything else is `"ios"`, a missing agent included, because
  every build of the app before the Android one is an iOS build, and those
  send `app/<build> CFNetwork/<version> Darwin/<version>`
  (docs/IOS_API_CONTRACT.md, C3), which names no platform at all.

  Only `:record_from_app` runs this. `:record` takes its source from the
  server-side caller, and v1's controller still says `"ios"` itself, since
  only the iOS app calls v1.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :source,
      source(changeset.context[:user_agent])
    )
  end

  @doc """
  The surface a user agent belongs to: `"android"` or `"ios"`.
  """
  def source(user_agent) when is_binary(user_agent) do
    if String.contains?(String.downcase(user_agent), "android"), do: "android", else: "ios"
  end

  def source(_no_agent), do: "ios"
end
