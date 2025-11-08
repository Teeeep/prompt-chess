import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = { matchId: String }

  connect() {
    console.log("Match subscription controller connected for match", this.matchIdValue)

    this.subscription = consumer.subscriptions.create(
      {
        channel: "MatchChannel",
        match_id: this.matchIdValue
      },
      {
        received: this.received.bind(this)
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  received(data) {
    console.log("Received data:", data)

    if (data.type === "move_added") {
      this.handleMoveAdded(data.move)
    } else if (data.type === "error") {
      this.handleError(data.message)
    }
  }

  handleMoveAdded(move) {
    // Update chess board
    const chessBoardElement = document.querySelector("[data-controller='chess-board']")
    if (chessBoardElement && this.application) {
      const chessBoardController = this.application.getControllerForElementAndIdentifier(
        chessBoardElement,
        "chess-board"
      )
      if (chessBoardController) {
        chessBoardController.positionValue = move.board_state_after
      }
    }

    // Re-enable submit button if it's a Stockfish move
    if (move.player === "stockfish") {
      const moveFormElement = document.querySelector("[data-controller='move-form']")
      if (moveFormElement && this.application) {
        const moveFormController = this.application.getControllerForElementAndIdentifier(
          moveFormElement,
          "move-form"
        )
        if (moveFormController && typeof moveFormController.enableSubmit === 'function') {
          moveFormController.enableSubmit()
        }
      }
    }

    // Check if game is over by checking match_completed field
    if (move.match_completed) {
      // Reload page to show final state
      window.location.reload()
    }
  }

  handleError(message) {
    alert(`Match error: ${message}`)
    // Reload page to show error state
    window.location.reload()
  }
}
