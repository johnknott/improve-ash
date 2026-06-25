defmodule Improve.Planning.ProjectedWorkTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.ProjectedWork

  describe "session/2" do
    test "wraps a projected session occurrence in the general projected work shape" do
      occurrence = %{
        plan_id: "plan-1",
        session_template_id: "template-1",
        session_template_name: "Upper gym",
        planned_for: ~D[2026-06-22],
        recommendations: [%{slot_key: "push"}]
      }

      work = ProjectedWork.session(occurrence)

      assert work.kind == :session
      assert work.status == :planned
      assert work.owner_type == :session_template
      assert work.owner_id == "template-1"
      assert work.title == "Upper gym"
      assert work.payload.session_occurrence == occurrence
      assert work.payload.recommendations == [%{slot_key: "push"}]
      assert work.explanation =~ "Projected Upper gym"
    end
  end

  describe "track/2" do
    test "represents a track target without pretending it is a session" do
      track = track()

      work =
        ProjectedWork.track(track,
          planned_for: ~D[2026-06-22],
          status: :completed,
          completed_event_ids: ["event-1"],
          target_progress: %{completed_event_count: 1},
          explanation: "Read pages was completed by one journal event."
        )

      assert work.kind == :track
      assert work.status == :completed
      assert work.owner_type == :track
      assert work.owner_id == "track-1"
      assert work.title == "Read pages"
      assert work.payload.track_id == "track-1"
      assert work.payload.track_key == "read_pages"
      assert work.payload.event_type_id == "event-type-1"
      assert work.payload.target == %{"quantity" => 20, "unit" => "pages"}
      assert work.payload.completed_event_ids == ["event-1"]
      assert work.payload.target_progress == %{completed_event_count: 1}
      assert work.explanation == "Read pages was completed by one journal event."
    end

    test "rejects unsupported target statuses" do
      assert_raise ArgumentError, ~r/Unsupported projected work status/, fn ->
        ProjectedWork.track(track(), planned_for: ~D[2026-06-22], status: :invented)
      end
    end
  end

  defp track do
    %{
      id: "track-1",
      plan_id: "plan-1",
      key: "read_pages",
      name: "Read pages",
      event_type_id: "event-type-1",
      target: %{"quantity" => 20, "unit" => "pages"},
      completion_policy: %{"mode" => "at_least_target"},
      missed_policy: %{"mode" => "miss_if_no_event_by_end_of_day"}
    }
  end
end
