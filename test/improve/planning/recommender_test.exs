defmodule Improve.Planning.RecommenderTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Recommender

  describe "adaptive suggestions" do
    test "uses cold-start payload when no history exists" do
      [recommendation] =
        Recommender.recommend_slot(slot(), %{
          pool_memberships: [%{pool_id: "practice", item_id: "item-1"}],
          items: [item()],
          journal_events: []
        })

      assert recommendation.item_id == "item-1"

      assert recommendation.suggested_payload == %{
               "duration_minutes" => 10,
               "effort" => "easy",
               "rounds" => 2
             }

      assert recommendation.source == "cold_start"
      assert recommendation.reason == "A starting suggestion — adjust as you go."
      assert recommendation.previous_event_ids == []
      assert recommendation.previous_events == []
    end

    test "suggests generic field values from the most recent linked event" do
      [recommendation] =
        Recommender.recommend_slot(slot(), %{
          pool_memberships: [%{pool_id: "practice", item_id: "item-1"}],
          items: [item()],
          journal_events: [
            event("older-event", ~U[2026-06-20 08:00:00Z], %{
              "duration_minutes" => 8,
              "effort" => "easy",
              "rounds" => 1
            }),
            event("latest-event", ~U[2026-06-22 08:00:00Z], %{
              "duration_minutes" => 12,
              "effort" => "steady",
              "ignored_field" => "not part of the adaptive target",
              "rounds" => 3
            })
          ]
        })

      assert recommendation.suggested_payload == %{
               "duration_minutes" => 12,
               "effort" => "steady",
               "rounds" => 3
             }

      assert recommendation.source == "history"

      assert recommendation.reason ==
               "Based on your last Practice slot entry."

      assert recommendation.previous_event_ids == ["latest-event", "older-event"]

      assert [
               %{
                 id: "latest-event",
                 summary: "Practice logged",
                 effective_at: "2026-06-22T08:00:00Z",
                 payload: %{"ignored_field" => "not part of the adaptive target"}
               },
               %{id: "older-event"}
             ] = recommendation.previous_events
    end
  end

  defp slot do
    %{
      pool_id: "practice",
      count: 1,
      name: "Practice slot",
      rules: %{
        "suggestion_target" => %{
          "type" => "adaptive",
          "fields" => ["rounds", "duration_minutes"],
          "effort" => "effort",
          "review" => "weekly"
        },
        "cold_start_payload" => %{
          "duration_minutes" => 10,
          "effort" => "easy",
          "rounds" => 2
        }
      }
    }
  end

  defp item do
    %{id: "item-1", key: "item_1", name: "Item 1", archived_at: nil}
  end

  defp event(id, happened_at, payload) do
    %{
      id: id,
      status: :active,
      summary: "Practice logged",
      effective_at: happened_at,
      recorded_at: happened_at,
      payload: payload,
      event_item_links: [%{item_id: "item-1"}]
    }
  end
end
