defmodule LumenViae.Repo do
  use Ecto.Repo,
    otp_app: :lumen_viae,
    adapter: Ecto.Adapters.Postgres
end
