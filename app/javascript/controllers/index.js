// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Explicitly register custom controllers
import ChessBoardController from "controllers/chess_board_controller"
application.register("chess-board", ChessBoardController)

import MatchSubscriptionController from "controllers/match_subscription_controller"
application.register("match-subscription", MatchSubscriptionController)

import MoveFormController from "controllers/move_form_controller"
application.register("move-form", MoveFormController)
