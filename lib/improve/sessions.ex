defmodule Improve.Sessions do
  use Ash.Domain,
    otp_app: :improve

  resources do
    resource Improve.Sessions.SessionOccurrence do
      define :create_session_occurrence, action: :create_projected
      define :get_session_occurrence, action: :read, get_by: [:id]
      define :list_session_occurrences, action: :read
      define :start_session_occurrence, action: :start
      define :complete_session_occurrence, action: :complete
      define :mark_session_occurrence_skipped, action: :mark_skipped
      define :mark_session_occurrence_missed, action: :mark_missed
    end

    resource Improve.Sessions.SlotResult do
      define :create_slot_result, action: :create
      define :get_slot_result, action: :read, get_by: [:id]
      define :list_slot_results, action: :read
      define :complete_slot_result, action: :complete
      define :swap_slot_result, action: :swap
    end
  end
end
