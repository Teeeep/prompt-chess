// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Explicitly register custom controllers
import ChessBoardController from "./chess_board_controller"
application.register("chess-board", ChessBoardController)
