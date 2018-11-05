import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import socket from '../socket'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { onScrollBottom } from '../lib/utils'
import listMorph from '../lib/list_morph'

export const initialState = {
  channelDisconnected: false,

  blocks: [],

  loadingNextPage: false,
  pagingError: false,
  nextPageUrl: null
}

export const reducer = withMissingBlocks(baseReducer)

function baseReducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'CHANNEL_DISCONNECTED': {
      return Object.assign({}, state, {
        channelDisconnected: true
      })
    }
    case 'RECEIVED_NEW_BLOCK': {
      if (state.channelDisconnected) return state

      if (!state.blocks.length || state.blocks[0].blockNumber < action.msg.blockNumber) {
        return Object.assign({}, state, {
          blocks: [
            action.msg,
            ...state.blocks
          ]
        })
      } else {
        return Object.assign({}, state, {
          blocks: state.blocks.map((block) => block.blockNumber === action.msg.blockNumber ? action.msg : block)
        })
      }
    }
    case 'LOADING_NEXT_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: true
      })
    }
    case 'PAGING_ERROR': {
      return Object.assign({}, state, {
        loadingNextPage: false,
        pagingError: true
      })
    }
    case 'RECEIVED_NEXT_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: false,
        nextPageUrl: action.msg.nextPageUrl,
        blocks: [
          ...state.blocks,
          ...action.msg.blocks
        ]
      })
    }
    default:
      return state
  }
}

function withMissingBlocks (reducer) {
  return (...args) => {
    const result = reducer(...args)

    if (result.blocks.length < 2) return result

    const maxBlock = _.first(result.blocks).blockNumber
    const minBlock = _.last(result.blocks).blockNumber

    return Object.assign({}, result, {
      blocks: _.rangeRight(minBlock, maxBlock + 1)
        .map((blockNumber) => _.find(result.blocks, ['blockNumber', blockNumber]) || {
          blockNumber,
          blockHtml: placeHolderBlock(blockNumber)
        })
    })
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render ($el, state) {
      if (state.channelDisconnected) $el.show()
    }
  },
  '[data-selector="blocks-list"]': {
    load ($el) {
      return {
        blocks: $el.children().map((index, el) => ({
          blockNumber: parseInt(el.dataset.blockNumber),
          blockHtml: el.outerHTML
        })).toArray()
      }
    },
    render ($el, state, oldState) {
      if (oldState.blocks === state.blocks) return
      const container = $el[0]
      const newElements = _.map(state.blocks, ({ blockHtml }) => $(blockHtml)[0])
      listMorph(container, newElements, { key: 'dataset.blockNumber' })
    }
  },
  '[data-selector="next-page-button"]': {
    load ($el) {
      return {
        nextPageUrl: `${$el.hide().attr('href')}&type=JSON`
      }
    }
  },
  '[data-selector="loading-next-page"]': {
    render ($el, state) {
      if (state.loadingNextPage) {
        $el.show()
      } else {
        $el.hide()
      }
    }
  },
  '[data-selector="paging-error-message"]': {
    render ($el, state) {
      if (state.pagingError) {
        $el.show()
      }
    }
  }
}

const $blockListPage = $('[data-page="block-list"]')
if ($blockListPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

  const blocksChannel = socket.channel(`blocks:new_block`, {})
  blocksChannel.join()
  blocksChannel.onError(() => store.dispatch({
    type: 'CHANNEL_DISCONNECTED'
  }))
  blocksChannel.on('new_block', (msg) => store.dispatch({
    type: 'RECEIVED_NEW_BLOCK',
    msg: humps.camelizeKeys(msg)
  }))

  onScrollBottom(() => {
    const { loadingNextPage, nextPageUrl, pagingError } = store.getState()
    if (!loadingNextPage && nextPageUrl && !pagingError) {
      store.dispatch({
        type: 'LOADING_NEXT_PAGE'
      })
      $.get(nextPageUrl)
        .done(msg => {
          store.dispatch({
            type: 'RECEIVED_NEXT_PAGE',
            msg: humps.camelizeKeys(msg)
          })
        })
        .fail(() => {
          store.dispatch({
            type: 'PAGING_ERROR'
          })
        })
    }
  })
}

export function placeHolderBlock (blockNumber) {
  return `
    <div class="my-3" style="height: 98px;" data-selector="place-holder" data-block-number="${blockNumber}">
      <div
        class="tile tile-type-block d-flex align-items-center fade-up"
        style="height: 98px;"
      >
        <span class="loading-spinner-small ml-1 mr-4">
          <span class="loading-spinner-block-1"></span>
          <span class="loading-spinner-block-2"></span>
        </span>
        <div>
          <div class="tile-title">${blockNumber}</div>
          <div>${window.localized['Block Processing']}</div>
        </div>
      </div>
    </div>
  `
}
