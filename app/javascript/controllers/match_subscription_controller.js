import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static values = { matchId: String }

  connect() {
    console.log("Match subscription controller connected for match", this.matchIdValue)

    this.subscription = consumer.subscriptions.create(
      {
        channel: "GraphqlChannel"
      },
      {
        connected: () => {
          console.log("WebSocket connected, subscribing to match updates...")
          this.subscribe()
        },

        disconnected: () => {
          console.log("WebSocket disconnected")
        },

        received: (data) => {
          console.log("Received subscription data:", data)

          if (data.result && data.result.data && data.result.data.matchUpdated) {
            this.handleMatchUpdate(data.result.data.matchUpdated)
          }
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribe() {
    const query = `
      subscription($matchId: ID!) {
        matchUpdated(matchId: $matchId) {
          match {
            id
            status
            totalMoves
            totalTokensUsed
            totalCostCents
            winner
            resultReason
          }
          latestMove {
            id
            moveNumber
            player
            moveNotation
          }
        }
      }
    `

    this.subscription.send({
      query: query,
      variables: { matchId: this.matchIdValue },
      operationName: null
    })
  }

  handleMatchUpdate(data) {
    console.log("Match updated:", data)

    // Reload the page to show updates (simple MVP approach)
    // In production, would use Turbo Streams for targeted updates
    window.location.reload()
  }
}
