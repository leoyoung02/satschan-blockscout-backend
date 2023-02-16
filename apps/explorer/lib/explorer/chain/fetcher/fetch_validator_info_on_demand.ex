defmodule Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand do
  @moduledoc """
    On demand fetcher info about validator
  """

  use GenServer

  alias Explorer.Application.Constants
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Validator

  def trigger_fetch(address_hash) do
    GenServer.cast(__MODULE__, {:fetch_or_update, address_hash})
  end

  defp actualize_validator_info(address_hash) do
    contract_address_from_db = Constants.get_keys_manager_contract_address()

    contract_address_from_env =
      Application.get_env(:explorer, Explorer.Chain.Block.Reward, %{})[:keys_manager_contract_address]

    cond do
      is_nil(contract_address_from_env) ->
        :ignore

      is_nil(contract_address_from_db) ->
        Validator.drop_all_validators()
        Constants.insert_keys_manager_contract_address(contract_address_from_env)
        fetch_and_store_validator_info(address_hash)

      String.downcase(contract_address_from_db.value) == contract_address_from_env |> String.downcase() ->
        fetch_and_store_validator_info(address_hash)

      true ->
        Validator.drop_all_validators()
        Constants.insert_keys_manager_contract_address(contract_address_from_env)
        fetch_and_store_validator_info(address_hash)
    end
  end

  defp fetch_and_store_validator_info(validator_address) do
    validator = Validator.get_validator_by_address_hash(validator_address)
    %{is_validator: is_validator, payout_key: payout_key} = Reward.get_validator_payout_key_by_mining(validator_address)

    Validator.insert_or_update(validator, %{
      address_hash: validator_address,
      is_validator: is_validator,
      payout_key_hash: payout_key,
      last_block_updated_at: BlockNumber.get_max()
    })
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_cast({:fetch_or_update, address_hash}, state) do
    actualize_validator_info(address_hash)

    {:noreply, state}
  end
end
