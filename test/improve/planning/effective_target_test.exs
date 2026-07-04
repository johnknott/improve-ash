defmodule Improve.Planning.EffectiveTargetTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.EffectiveTarget

  describe "from_authored/1" do
    test "wraps a target map as unadjusted" do
      target = %{"type" => "period_total", "quantity" => 100, "unit" => "km", "per" => "week"}
      et = EffectiveTarget.from_authored(target)

      assert et.authored == target
      assert et.effective == target
      assert et.adjusted? == false
      assert et.source == nil
      assert et.reason == nil
    end
  end

  describe "adjust/3" do
    test "merges adjustment into authored to produce effective" do
      target = %{"type" => "period_total", "quantity" => 100, "unit" => "km", "per" => "week"}
      et = EffectiveTarget.from_authored(target)

      adjusted =
        EffectiveTarget.adjust(et, %{"quantity" => 80},
          source: :marathon_adaptation,
          reason: "Recent load is low after illness"
        )

      assert adjusted.authored == target
      assert adjusted.effective == %{"type" => "period_total", "quantity" => 80, "unit" => "km", "per" => "week"}
      assert adjusted.adjusted? == true
      assert adjusted.source == :marathon_adaptation
      assert adjusted.reason == "Recent load is low after illness"
    end

    test "target_for_completion returns the effective map" do
      target = %{"type" => "progression", "from" => 10, "to" => 42}
      et = EffectiveTarget.from_authored(target)

      adjusted = EffectiveTarget.adjust(et, %{"to" => 35}, source: :deload)

      assert EffectiveTarget.target_for_completion(adjusted) == %{
               "type" => "progression",
               "from" => 10,
               "to" => 35
             }
    end
  end

  describe "to_snapshot/1" do
    test "serializes unadjusted target" do
      target = %{"type" => "fixed"}
      et = EffectiveTarget.from_authored(target)

      snapshot = EffectiveTarget.to_snapshot(et)

      assert snapshot == %{
               "authored" => %{"type" => "fixed"},
               "effective" => %{"type" => "fixed"},
               "adjusted" => false
             }
    end

    test "serializes adjusted target with source and reason" do
      target = %{"type" => "period_total", "quantity" => 50}
      et = EffectiveTarget.from_authored(target)

      adjusted =
        EffectiveTarget.adjust(et, %{"quantity" => 30},
          source: :marathon_adaptation,
          reason: "Deload after illness"
        )

      snapshot = EffectiveTarget.to_snapshot(adjusted)

      assert snapshot == %{
               "authored" => %{"type" => "period_total", "quantity" => 50},
               "effective" => %{"type" => "period_total", "quantity" => 30},
               "adjusted" => true,
               "source" => "marathon_adaptation",
               "reason" => "Deload after illness"
             }
    end
  end

  describe "integration with projector" do
    test "unadjusted effective target evaluates same as authored" do
      target = %{"type" => "period_total", "quantity" => 100, "unit" => "km", "per" => "week"}
      et = EffectiveTarget.from_authored(target)

      assert EffectiveTarget.target_for_completion(et) == target
    end

    test "adjusted effective target changes the completion threshold" do
      target = %{"type" => "period_total", "quantity" => 100, "unit" => "km", "per" => "week"}
      et = EffectiveTarget.from_authored(target)

      adjusted = EffectiveTarget.adjust(et, %{"quantity" => 70}, source: :illness_deload)

      effective = EffectiveTarget.target_for_completion(adjusted)
      assert effective["quantity"] == 70
    end
  end
end
