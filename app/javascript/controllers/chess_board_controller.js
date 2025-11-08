import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { position: String }

  connect() {
    console.log("Chess board controller connected")
    this.board = Chessboard(this.element, {
      position: this.positionValue,
      draggable: false,
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
