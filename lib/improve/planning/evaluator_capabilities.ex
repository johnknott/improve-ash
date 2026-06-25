defmodule Improve.Planning.EvaluatorCapabilities do
  @moduledoc """
  Minimal evaluator capability descriptors for the first real dependency.

  Descriptors are data only: they make provided and required capabilities
  visible to the host. Ordering, caching, and evaluator execution belong to the
  next slice.
  """

  @type capability :: atom()
  @type evaluator_name :: atom()

  @type descriptor :: %{
          required(:evaluator) => evaluator_name(),
          required(:kind) => atom(),
          required(:provides) => [capability()],
          required(:requires) => [capability()]
        }

  @type dependency_edge :: %{
          required(:provider) => evaluator_name(),
          required(:consumer) => evaluator_name(),
          required(:capability) => capability()
        }

  @marathon_descriptors [
    %{
      evaluator: :recent_load_metric,
      kind: :derived_metric,
      provides: [:recent_load_km],
      requires: [:as_of_date, :tracks, :journal_events]
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
  Returns the two descriptors that force the first evaluator dependency.
  """
  @spec marathon_descriptors() :: [descriptor()]
  def marathon_descriptors do
    @marathon_descriptors
  end

  @doc """
  Indexes descriptors by the capabilities they provide.
  """
  @spec providers_by_capability([descriptor()]) :: %{capability() => [descriptor()]}
  def providers_by_capability(descriptors) when is_list(descriptors) do
    descriptors
    |> Enum.reduce(%{}, fn descriptor, acc ->
      Enum.reduce(descriptor.provides, acc, fn capability, acc ->
        Map.update(acc, capability, [descriptor], &[descriptor | &1])
      end)
    end)
    |> Map.new(fn {capability, providers} ->
      {capability, Enum.reverse(providers)}
    end)
  end

  @doc """
  Returns visible evaluator dependencies implied by `provides`/`requires`.

  This deliberately stops at edge discovery. Topological ordering, caching, and
  running evaluators are handled by the next bean.
  """
  @spec dependency_edges([descriptor()]) :: [dependency_edge()]
  def dependency_edges(descriptors) when is_list(descriptors) do
    providers = providers_by_capability(descriptors)

    for consumer <- descriptors,
        capability <- consumer.requires,
        provider <- Map.get(providers, capability, []),
        provider.evaluator != consumer.evaluator do
      %{
        provider: provider.evaluator,
        consumer: consumer.evaluator,
        capability: capability
      }
    end
  end
end
