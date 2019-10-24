defmodule BlockScoutWeb.Tokens.ReadContractController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}

  def index(conn, %{"token_id" => address_hash_string}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash, options) do
      render(
        conn,
        "index.html",
        token: Market.add_price(token),
        counters_path: token_path(conn, :token_counters, %{"id" => to_string(address_hash)})
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
