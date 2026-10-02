defmodule LumenViae.Accounts.Admin do
  @moduledoc """
  Someone who may sign in to the console at `/admin`.

  Signed in with an email and a password (AshAuthentication's password
  strategy), and nothing else: there is no public registration, no magic
  link and no reset email, because production has no mailer and the
  console has a handful of users. An admin is created, and a forgotten
  password replaced, from a production shell with
  `LumenViae.Release.create_admin/1` and
  `LumenViae.Release.reset_admin_password/1`; see docs/PROD_ACCESS.md.

  An admin is the actor every console action runs as, and
  `LumenViae.Accounts.Checks.ActorIsAdmin` is the check every resource's
  policies open with.

  Reach admins through `LumenViae.Accounts`. The router names this module
  because AshAuthentication's routes are declared per resource; nothing
  else outside `lib/lumen_viae/accounts/` does.
  """
  use Ash.Resource,
    otp_app: :lumen_viae,
    domain: LumenViae.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  @password_constraints [min_length: 12, max_length: 72]

  postgres do
    table "admins"
    repo LumenViae.Repo
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(LumenViae.Accounts.Token)
      signing_secret(LumenViae.Accounts.Secrets)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)
    end

    strategies do
      password :password do
        identity_field(:email)
        hash_provider(AshAuthentication.BcryptProvider)
        registration_enabled?(false)
        sign_in_tokens_enabled?(false)
      end
    end

    # A new password revokes every session the admin has open (see the
    # :set_password action for why it is also named there).
    add_ons do
      log_out_everywhere do
        apply_on_password_change?(true)
      end
    end
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get an admin by the subject claim in a JWT."
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up an admin by email."
      get_by :email
    end

    read :sign_in_with_password do
      description "Attempt to sign in using an email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the admin."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching admin."
        allow_nil? false
        sensitive? true
      end

      # Validates the email and password and generates a token.
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the admin."
        allow_nil? false
      end
    end

    create :create do
      description "Creates an admin with a password. Run from a production shell, never from the web."
      primary? true
      accept [:email]

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    update :set_password do
      description "Replaces an admin's password, which signs them out everywhere."
      require_atomic? false
      accept []

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}

      # Named here as well as by the add-on: the add-on attaches it only
      # `where: changing(:hashed_password)`, which is decided before the
      # hash above is set, so on its own it never revokes anything.
      change AshAuthentication.AddOn.LogOutEverywhere.OnPasswordChange
    end
  end

  policies do
    # Signing in, loading the admin from a session and revoking tokens are
    # AshAuthentication's own reads and writes, made before there is an
    # actor to authorize.
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end
end
