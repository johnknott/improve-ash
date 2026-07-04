defmodule Improve.Bundles.Strength do
  @moduledoc """
  Adaptive strength training bundle.

  Proves the evaluator contract generalizes beyond the marathon bundle.
  Uses responsive progression (performance-gated), deload detection, and
  adjust_goal proposals — sharing zero marathon code.

  Evaluator pipeline:
  - `strength_fatigue`: derives fatigue signal from recent session density
  - `strength_adaptation`: uses progression_positions + fatigue to propose
    deload weeks or goal adjustments
  """

  @descriptors [
    %{
      evaluator: :strength_fatigue,
      kind: :derived_metric,
      provides: [:strength_fatigue],
      requires: [:date, :tracks, :journal_events, :timezone]
    },
    %{
      evaluator: :strength_adaptation,
      kind: :adaptation,
      provides: [:strength_adaptation],
      requires: [
        :date,
        :tracks,
        :journal_events,
        :projected_work,
        :strength_fatigue,
        :progression_positions
      ]
    }
  ]

  def evaluator_descriptors do
    @descriptors
  end
end
