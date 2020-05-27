import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
import { makeContractCall, setupChart, isSupportedNetwork } from './utils'

export function openMakeStakeModal (event, store) {
  if (!store.getState().account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  if (!isSupportedNetwork(store)) return

  const address = $(event.target).closest('[data-address]').data('address') || store.getState().account

  store.getState().channel
    .push('render_make_stake', { address })
    .receive('ok', msg => {
      const $modal = $(msg.html)
      const $form = $modal.find('form')

      setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.total_staked_amount)

      setupValidation(
        $form,
        {
          'delegator-stake': value => isDelegatorStakeValid(value, store, msg, address)
        },
        $modal.find('form button')
      )

      $modal.find('[data-available-amount]').click(e => {
        const amount = $(e.currentTarget).data('available-amount')
        $('[delegator-stake]', $form).val(amount).trigger('input')
        $('.tooltip').tooltip('hide')
        return false
      })

      $form.submit(() => {
        makeStake($modal, address, store, msg)
        return false
      })

      openModal($modal)
    })
}

function makeStake ($modal, address, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals

  const stake = new BigNumber($modal.find('[delegator-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  makeContractCall(stakingContract.methods.stake(address, stake.toString()), store)
}

function isDelegatorStakeValid (value, store, msg, address) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const account = store.getState().account

  if (!stake.isPositive() || stake.isZero()) {
    return 'Invalid amount'
  } else if (stake.plus(currentStake).isLessThan(minStake)) {
    const staker = (account.toLowerCase() === address.toLowerCase()) ? 'candidate' : 'delegate'
    return `Minimum ${staker} stake is ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`
  } else if (stake.isGreaterThan(balance)) {
    return 'Insufficient funds'
  }

  return true
}
