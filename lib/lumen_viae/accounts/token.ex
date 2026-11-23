defmodule LumenViae.Accounts.Token do
  @moduledoc """
  The admin session tokens AshAuthentication issues, and the revocations
  that sign-out and a password reset leave behind.

  Every token is stored (`store_all_tokens?` on the admin resource), and a
  session is only honoured while its token is here and unrevoked, so
  signing out really ends the session rather than waiting for the JWT to
  expire.

  Only AshAuthentication itself touches this resource; nothing outside
  `lib/lumen_viae/accounts/` names it.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "admin_tokens"
    repo LumenViae.Repo
  end

  actions do
    defaults [:read]

    read :expired do
      description "Look up all expired tokens."
      filter expr(expires_at < now())
    end

    read :get_token do
      description "Look up a token by JTI or token, and an optional purpose."
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string, sensitive?: false

      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked?, :boolean do
      description "Returns true if a revocation token is found for the provided token"
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true

      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      description "Revoke a token. Creates a revocation token corresponding to the provided token."
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeTokenChange
    end

    create :revoke_jti do
      description "Revoke a token by JTI. Creates a revocation token corresponding to the provided jti."
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      argument :jti, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeJtiChange
    end

    create :store_token do
      description "Stores a token used for the provided purpose."
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.StoreTokenChange
    end

    # The Admins screen's "Last signed in": a session token is stored at
    # each sign-in and kept until it expires, so this reaches back as far
    # as the token lifetime. Only the subject and the moment are selected.
    read :sign_ins do
      description "When each admin's stored sessions began, newest first: subject and time only."
      # Sign-out revokes a session by upserting its jti with purpose
      # "revocation" and keeps created_at, so a signed-out session still
      # says when it began.
      filter expr(purpose in ["user", "revocation"])
      prepare build(select: [:subject, :created_at], sort: [created_at: :desc])
    end

    destroy :expunge_expired do
      description "Deletes expired tokens."
      change filter(expr(expires_at < now()))
    end

    update :revoke_all_stored_for_subject do
      description "Revokes all stored tokens for a specific subject."
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.RevokeAllStoredForSubjectChange
    end
  end

  # Only AshAuthentication reads and writes tokens, and a token is a
  # credential. The one exception is :sign_ins, which an admin may read for
  # the Admins screen: it selects who and when, never the token.
  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      description "AshAuthentication can interact with the token resource"
      authorize_if always()
    end

    policy action(:sign_ins) do
      authorize_if LumenViae.Accounts.Checks.ActorIsAdmin
    end
  end

  attributes do
    attribute :jti, :string do
      primary_key? true
      public? true
      allow_nil? false
      sensitive? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :extra_data, :map do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end
end
