import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { position: String }

  connect() {
    this.board = Chessboard(this.element, {
      position: this.positionValue,
      draggable: false,
      // Use locally-hosted piece images to avoid CORS/ORB errors from external CDN
      pieceTheme: '/img/chesspieces/wikipedia/{piece}.png'
    })
  }

  disconnect() {
    if (this.board) {
      this.board.destroy()
    }
  }

  positionValueChanged() {
    if (this.board) {
      this.board.position(this.positionValue)
    }
  }
}
