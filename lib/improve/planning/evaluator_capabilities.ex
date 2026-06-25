defmodule Improve.Planning.EvaluatorCapabilities do
  @moduledoc """
  Minimal evaluator capability helpers.

  Descriptors are data only: they make provided and required capabilities
  visible to the host. Ordering, caching, and evaluator execution belong to
  `Improve.Planning.EvaluatorGraph`.
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
  running evaluators are handled by `Improve.Planning.EvaluatorGraph`.
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
