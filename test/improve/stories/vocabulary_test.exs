defmodule Improve.Stories.VocabularyTest do
  use Improve.DataCase, async: true

  import ExUnit.CaptureIO

  alias Improve.Stories, as: Story

  @story_dir Path.expand("../../../priv/scripts/stories", __DIR__)
  @expected_story_files [
    "01_track_reading.exs",
    "02_track_target_types.exs",
    "03_schedule_shapes.exs",
    "04_session_from_pools.exs",
    "05_adaptive_item_work.exs",
    "06_stateful_item_effects.exs",
    "07_offline_and_correction.exs",
    "08_review_and_adjustment.exs",
    "09_full_life_plan.exs",
    "10_adaptive_marathon.exs"
  ]

  @removed_terms [
    "Direct" <> "Goal",
    "direct" <> "_goal",
    "direct" <> "Goal",
    "direct" <> "-goal",
    "add" <> "_exercise!",
    "log" <> "_direct" <> "_goal!"
  ]

  @simple_output_terms [
    "direct" <> "_goal",
    "Direct" <> "Goal",
    "payload",
    "effect",
    "link"
  ]

  describe "story script vocabulary" do
    test "keeps the numbered story set aligned to product questions" do
      files =
        @story_dir
        |> Path.join("*.exs")
        |> Path.wildcard()
        |> Enum.map(&Path.basename/1)
        |> Enum.sort()

      assert files == @expected_story_files
    end

    test "keeps removed goal terms out of product-facing code and stories" do
      scanned_text =
        [
          "lib",
          "priv/scripts/stories",
          "notes/product-story-scripts.md"
        ]
        |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*")))
        |> Enum.reject(&File.dir?/1)
        |> Enum.map(&File.read!/1)
        |> Enum.join("\n")

      for term <- @removed_terms do
        refute scanned_text =~ term
      end
    end

    test "simple happy-path story output avoids raw implementation vocabulary" do
      story =
        Story.begin!("test_story_vocabulary", reset?: true)
        |> Story.user!("Story Vocabulary", email: "story+test-vocabulary@example.test")

      plan =
        Story.create_plan!(story, "Read more consistently",
          intention: "Read a little every day",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      Story.add_track!(story, plan, "Read 20 pages",
        key: "daily_reading",
        schedule: Story.every_day(),
        target: Story.fixed(20, "pages"),
        records: Story.number("pages")
      )

      output =
        capture_io(fn ->
          Story.show_plan_summary!(story, plan)
          today = Story.project_today!(story, plan, on: ~D[2026-06-23])
          Story.show_projection!(story, today)

          Story.log_track!(story, today,
            track: "daily_reading",
            payload: %{amount: 25, note: "Read before bed"}
          )

          Story.show_journal!(story, plan)
        end)

      for term <- @simple_output_terms do
        refute output =~ term
      end

      assert output =~ "Plan Summary"
      assert output =~ "Projected Work"
      assert output =~ "Journal"
      assert output =~ "Read 20 pages"
    end

    test "AI/debug story output may deliberately expose structured context" do
      story =
        Story.begin!("test_story_vocabulary_ai_context", reset?: true)
        |> Story.user!("Story Vocabulary AI", email: "story+test-vocabulary-ai@example.test")

      plan =
        Story.create_plan!(story, "Adaptive practice plan",
          intention: "Suggest the next useful work for each item",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      Story.add_event_type!(story, plan, "Practice logged",
        key: "practice_logged",
        required_links: ["item"],
        payload: %{required: ["rounds", "duration_minutes", "effort"]}
      )

      Story.add_item_type!(story, plan, "Practice item", key: "practice_item")
      Story.add_item!(story, plan, "Piano scales", key: "piano_scales", type: "practice_item")

      Story.add_pool!(story, plan, "Technique choices",
        key: "technique",
        items: ["piano_scales"]
      )

      Story.add_session!(story, plan, "Focused practice",
        key: "focused_practice",
        schedule: Story.every_week(times: 1, on: [:monday]),
        slots: [
          Story.choose(1,
            from: "technique",
            suggest: Story.adaptive(fields: [:rounds], effort: :effort, review: :weekly),
            start_with: %{rounds: 2, effort: "easy"}
          )
        ]
      )

      output =
        capture_io(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
        end)

      assert output =~ "AI Today Context"
      assert output =~ "suggested_payload"
    end
  end
end
