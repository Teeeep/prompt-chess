import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "error", "status"]

  async submit(event) {
    event.preventDefault()

    const notation = this.inputTarget.value.trim()
    if (!notation) {
      this.showError("Please enter a move")
      return
    }

    this.submitTarget.disabled = true
    this.clearError()
    this.showStatus("Submitting move...")

    try {
      const response = await this.submitMove(notation)

      if (response.success) {
        this.inputTarget.value = ""
        this.showStatus("Waiting for Stockfish...")
        // Button stays disabled until Stockfish move arrives via ActionCable
      } else {
        this.showError(response.error || "Failed to submit move")
        this.submitTarget.disabled = false
        this.clearStatus()
      }
    } catch (error) {
      console.error("Error submitting move:", error)
      this.showError("An error occurred while submitting the move")
      this.submitTarget.disabled = false
      this.clearStatus()
    }
  }

  async submitMove(notation) {
    const matchId = this.element.dataset.matchId

    const query = `
      mutation($input: SubmitMoveInput!) {
        submitMove(input: $input) {
          success
          move {
            id
            moveNotation
            player
          }
          error
        }
      }
    `

    const response = await fetch("/graphql", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({
        query,
        variables: {
          input: {
            matchId,
            moveNotation: notation
          }
        }
      })
    })

    const { data } = await response.json()
    return data.submitMove
  }

  showError(message) {
    this.errorTarget.textContent = message
  }

  clearError() {
    this.errorTarget.textContent = ""
  }

  showStatus(message) {
    this.statusTarget.textContent = message
  }

  clearStatus() {
    this.statusTarget.textContent = ""
  }

  // Called from match_subscription_controller when Stockfish move arrives
  enableSubmit() {
    this.submitTarget.disabled = false
    this.clearStatus()
  }
}
