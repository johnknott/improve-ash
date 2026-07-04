defmodule Improve.Bundles.Marathon do
  @moduledoc """
  Internal marathon forcing-example bundle.

  This namespace keeps marathon-specific evaluator descriptors and decision
  logic out of the generic Improve planning core. The generic core still owns
  the evaluator graph and capability helper functions.
  """

  @descriptors [
    %{
      evaluator: :recent_load_metric,
      kind: :derived_metric,
      provides: [:recent_load_km],
      requires: [:as_of_date, :tracks, :journal_events, :timezone]
    },
    %{
      evaluator: :marathon_target_adjustment,
      kind: :target_adjustment,
      provides: [:derived_target_adjustments],
      requires: [:date, :tracks, :life_events, :recent_load_km]
    },
    %{
      evaluator: :marathon_adaptation,
      kind: :adaptation,
      provides: [:marathon_adaptation],
      requires: [
        :date,
        :projected_work,
        :recent_missed_work,
        :journal_events,
        :life_events,
        :time_off_windows,
        :plan_skeleton,
        :track_guidance,
        :recent_load_km
      ]
    }
  ]

  @doc """
  Returns the evaluator descriptors used by the adaptive marathon story.
  """
  def evaluator_descriptors do
    @descriptors
  end
end
