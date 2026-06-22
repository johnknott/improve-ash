defmodule Improve.Ai do
  use Ash.Domain,
    extensions: [AshAi],
    otp_app: :improve

  tools do
    tool(:project_today, Improve.Ai.ReadTool, :project_today,
      description: "Project today's planned work for an owned plan without mutating history."
    )

    tool(:get_plan_summary, Improve.Ai.ReadTool, :get_plan_summary,
      description: "Return counts of authored content for an owned plan."
    )

    tool(:get_recent_journal_events, Improve.Ai.ReadTool, :get_recent_journal_events,
      description: "Return recent journal events for an owned plan."
    )

    tool(:get_item_state, Improve.Ai.ReadTool, :get_item_state,
      description: "Return derived state for an owned item."
    )
  end

  resources do
    resource Improve.Ai.ReadTool do
      define :project_today, args: [:plan_id, :date]
      define :get_plan_summary, args: [:plan_id]
      define :get_recent_journal_events, args: [:plan_id, :limit]
      define :get_item_state, args: [:item_id]
    end
  end
end
