defmodule LumenViae.Accounts.Admin do
  @moduledoc """
  Someone who may sign in to the console at `/admin`.

  Signed in with an email and a password (AshAuthentication's password
  strategy), and nothing else: there is no public registration, no magic
  link and no reset email, because production has no mailer and the
  console has a handful of users. An admin is created, and a forgotten
  password replaced, by another admin on the console's Admins screen (the
  `:add`, `:reset_password` and `:change_password` actions, each asking for
  the acting admin's own password), or from a production shell with
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
    extensions: [AshAuthentication, AshRateLimiter]

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
      # A week, not the 14-day default: a stolen cookie stops working sooner,
      # at the cost of signing in once a week.
      token_lifetime({7, :days})
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

  # The counters behind ConfirmActorPassword's attempt limit.
  rate_limit do
    backend LumenViae.Limits.Backend
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

    read :alphabetical do
      description "Every admin, by email: the console's Admins screen."
      prepare build(sort: [email: :asc])
    end

    # The console's three account actions. Each asks for the acting admin's
    # own password (ConfirmActorPassword), so a stolen session cookie
    # cannot add an admin or replace a password. See docs/ARCHITECTURE.md,
    # "The Accounts domain".

    create :add do
      description "Adds an admin from the console, with a generated password shown once. Needs the acting admin's own password."
      accept [:email]

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :current_password, :string do
        allow_nil? false
        sensitive? true
      end

      change LumenViae.Accounts.Admin.ConfirmActorPassword
      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    update :reset_password do
      description "Replaces another admin's password with a generated one, shown once, which signs them out everywhere. Needs the acting admin's own password."
      require_atomic? false
      accept []

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :current_password, :string do
        allow_nil? false
        sensitive? true
      end

      validate {LumenViae.Accounts.Admin.ActorIs, self?: false}
      change LumenViae.Accounts.Admin.ConfirmActorPassword
      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      change AshAuthentication.AddOn.LogOutEverywhere.OnPasswordChange
    end

    update :change_password do
      description "Replaces the acting admin's own password with one they choose, which signs them out everywhere, here included. Needs their current password."
      require_atomic? false
      accept []

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :password_confirmation, :string do
        allow_nil? false
        sensitive? true
      end

      argument :current_password, :string do
        allow_nil? false
        sensitive? true
      end

      validate confirm(:password, :password_confirmation)
      validate {LumenViae.Accounts.Admin.ActorIs, self?: true}
      change LumenViae.Accounts.Admin.ConfirmActorPassword
      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      change AshAuthentication.AddOn.LogOutEverywhere.OnPasswordChange
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

    # An admin may see who the admins are. Strict, so a read without an
    # admin is Forbidden rather than quietly empty.
    policy action_type(:read) do
      access_type :strict
      authorize_if LumenViae.Accounts.Checks.ActorIsAdmin
    end

    # From the console, an admin may add an admin, replace another admin's
    # password, and change their own - each only with their own password
    # typed again (ConfirmActorPassword), so a hijacked session cookie alone
    # cannot plant an admin or lock one out. Nothing else is authorized for
    # any actor: :create and :set_password run only from a production shell
    # (LumenViae.Release), with `authorize?: false`, and there is no destroy.
    # This resource has no admin bypass on purpose.
    policy action([:add, :reset_password, :change_password]) do
      authorize_if LumenViae.Accounts.Checks.ActorIsAdmin
    end
  end

  preparations do
    # The password hash is AshAuthentication's alone; see the module.
    prepare LumenViae.Accounts.Admin.HidePasswordHash
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
