defmodule Explorer.Accounts.Notify do
  @moduledoc """
    Interface for notifier, for import and call from other modules
  """

  alias Explorer.Accounts.Notifier.Notify

  require Logger

  def async(transactions) do
    Task.async(fn -> process(transactions) end)
  end

  defp process(transactions) do
    check_envs()
    Notify.call(transactions)
  rescue
    err ->
      Logger.info("--- Notifier error", fetcher: :account)
      Logger.info(err, fetcher: :account)
  end

  defp check_envs do
    check_auth0()
    check_sendgrid()
  end

  defp check_auth0 do
    (Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_id] &&
       Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_secret] &&
       Application.get_env(:ueberauth, Ueberauth)[:logout_return_to_url] &&
       Application.get_env(:ueberauth, Ueberauth)[:logout_url]) ||
      raise "Auth0 not configured"
  end

  defp check_sendgrid do
    (Application.get_env(:explorer, Explorer.Accounts)[:sendgrid][:sender] &&
       Application.get_env(:explorer, Explorer.Accounts)[:sendgrid][:template]) ||
      raise "SendGrid not configured"
  end
end
