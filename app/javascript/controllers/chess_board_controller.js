import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { position: String }

  connect() {
    console.log("Chess board controller connected")
    this.board = Chessboard('board', {
      position: this.positionValue,
      draggable: false
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
