defmodule Improve.Bundles.Marathon.PaceDerivationTest do
  use ExUnit.Case, async: true

  alias Improve.Bundles.Marathon.PaceDerivation

  describe "derive/2" do
    test "derives named paces from a 5k baseline with plus offsets" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:ok, outputs} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: 75},
                 marathon_pace: {:secs_per_km, :five_k, plus: 40}
               })

      # 25:00 5k -> 300 s/km.
      assert outputs.easy_pace == %{secs_per_km: 375, label: "6:15/km"}
      assert outputs.marathon_pace == %{secs_per_km: 340, label: "5:40/km"}
    end

    test "applies a minus offset for faster-than-baseline paces" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:ok, outputs} =
               PaceDerivation.derive(baseline, %{
                 interval_pace: {:secs_per_km, :five_k, minus: 5}
               })

      assert outputs.interval_pace == %{secs_per_km: 295, label: "4:55/km"}
    end

    test "derives the full marathon pace set from the story" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:ok, outputs} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: 75},
                 marathon_pace: {:secs_per_km, :five_k, plus: 40},
                 tempo_pace: {:secs_per_km, :five_k, plus: 25},
                 interval_pace: {:secs_per_km, :five_k, minus: 5}
               })

      assert outputs.easy_pace.label == "6:15/km"
      assert outputs.marathon_pace.label == "5:40/km"
      assert outputs.tempo_pace.label == "5:25/km"
      assert outputs.interval_pace.label == "4:55/km"
    end

    test "accepts string-keyed payloads the way stored events provide them" do
      baseline = %{"distance_km" => 5, "minutes" => 25, "seconds" => 30}

      assert {:ok, outputs} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: 75}
               })

      # (25*60 + 30) / 5 = 306 s/km; 306 + 75 = 381 -> 6:21/km.
      assert outputs.easy_pace == %{secs_per_km: 381, label: "6:21/km"}
    end

    test "derives from a 10k baseline when the recipe asks for ten_k" do
      baseline = %{"distance_km" => 10, "minutes" => 52}

      assert {:ok, outputs} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :ten_k, plus: 70}
               })

      assert outputs.easy_pace == %{secs_per_km: 382, label: "6:22/km"}
    end

    test "returns a plain-English diagnostic when the baseline lacks inputs" do
      baseline = %{distance_km: 5}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: 75}
               })

      assert diagnostic.output == :easy_pace
      assert diagnostic.details.field == :five_k
      assert diagnostic.message =~ "distance_km and minutes"
    end

    test "returns a diagnostic when the recipe baseline field does not match the payload distance" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :ten_k, plus: 75}
               })

      assert diagnostic.output == :easy_pace
      assert diagnostic.details.expected_distance_km == 10
      assert diagnostic.details.actual_distance_km == 5
      assert diagnostic.message =~ "needs a 10 km baseline"
    end

    test "returns a diagnostic for unsupported baseline fields" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :half_marathon, plus: 75}
               })

      assert diagnostic.output == :easy_pace
      assert diagnostic.details.field == :half_marathon
      assert diagnostic.message =~ "Supported fields are :five_k and :ten_k"
    end

    test "reports each failing output rather than aborting the whole recipe" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 good_pace: {:secs_per_km, :five_k, plus: 40},
                 bad_pace: {:laps_per_session, :five_k, plus: 1}
               })

      assert diagnostic.output == :bad_pace
      assert diagnostic.message =~ "Unsupported recipe entry"
    end

    test "returns a diagnostic instead of raising for invalid offset values" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: "soon"}
               })

      assert diagnostic.output == :easy_pace
      assert diagnostic.details.offset == %{plus: "soon"}
      assert diagnostic.message =~ "must be a number"
    end

    test "returns a diagnostic when both plus and minus are supplied" do
      baseline = %{distance_km: 5, minutes: 25}

      assert {:error, [diagnostic]} =
               PaceDerivation.derive(baseline, %{
                 easy_pace: {:secs_per_km, :five_k, plus: 75, minus: 5}
               })

      assert diagnostic.output == :easy_pace
      assert diagnostic.message =~ "either plus or minus"
    end
  end
end
