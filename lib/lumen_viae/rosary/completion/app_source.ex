defmodule LumenViae.Rosary.Completion.AppSource do
  @moduledoc """
  Sets which app a completion came from, on the user agent the server put
  in the action context (`:user_agent`, the one `Completion.NotAutomated`
  reads), never on anything the client named.

  `"android"` when the agent contains `Android`, in any case: the Android
  app identifies itself as
  `LumenViae-Android/<versionName> (Android <release>; <model>)`, and
  Android's own HTTP stack (`Dalvik/2.1.0 (Linux; U; Android 14; ...)`)
  says so too.

  `"ios"` when the agent is Apple's networking stack,
  `<name>/<build> CFNetwork/<version> Darwin/<version>`: every iOS build
  sends that (`app/5 CFNetwork/3826.500.111 Darwin/25.0.0`;
  docs/IOS_API_CONTRACT.md, C3), and it names no platform otherwise.

  Anything else, a missing agent included, is `"other"`: a script or an
  unknown client is not counted as an iPhone.

  Only `:record_from_app` runs this. `:record` takes its source from the
  server-side caller, and v1's controller still says `"ios"` itself, since
  only the iOS app calls v1.
  """
  use Ash.Resource.Change

  @apple ~r{\ACFNetwork/\S+ Darwin/\S+\z}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :source,
      source(changeset.context[:user_agent])
    )
  end

  @doc """
  The surface a user agent belongs to: `"android"`, `"ios"` or `"other"`.
  """
  def source(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(String.downcase(user_agent), "android") -> "android"
      apple?(user_agent) -> "ios"
      true -> "other"
    end
  end

  def source(_no_agent), do: "other"

  # The product token first (any name; the app's is `app`), then Apple's
  # two tokens and nothing after them.
  defp apple?(user_agent) do
    case String.split(String.trim(user_agent), " ", parts: 2) do
      [_product, rest] -> Regex.match?(@apple, rest)
      _one_token -> false
    end
  end
end
