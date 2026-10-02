defmodule LumenViae.Rosary.VersionPolicies do
  @moduledoc """
  The policies of the version resources AshPaperTrail generates for
  `Mystery`, `Meditation`, `MeditationSet` and `Author`.

  A version is history, read by an admin looking for what changed: an
  admin may read them, nobody else may, and nobody - admin included - may
  edit or delete one. Versions are written by the parent's own action,
  which AshPaperTrail runs unauthorized because the domain authorizes
  `:by_default`, so no create policy is needed here.

  Injected through each parent's `paper_trail do mixin ... end`, beside
  `version_extensions authorizers: [Ash.Policy.Authorizer]`.
  """
  defmacro __using__(_opts) do
    quote do
      policies do
        policy action_type(:read) do
          authorize_if LumenViae.Accounts.Checks.ActorIsAdmin
        end
      end
    end
  end
end
