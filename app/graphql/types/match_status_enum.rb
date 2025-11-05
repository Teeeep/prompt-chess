module Types
  class MatchStatusEnum < Types::BaseEnum
    description "Status of a chess match"

    value "PENDING", "Match created but not started", value: "pending"
    value "IN_PROGRESS", "Match currently being played", value: "in_progress"
    value "COMPLETED", "Match finished", value: "completed"
    value "ERRORED", "Match encountered an error", value: "errored"
  end
end
