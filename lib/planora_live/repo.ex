defmodule PlanoraLive.Repo do
  use Ecto.Repo,
    otp_app: :planora_live,
    adapter: Ecto.Adapters.Postgres
end
