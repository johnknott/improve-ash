defmodule Improve.Planning.EvaluatorGraph do
  @moduledoc """
  Minimal host machinery for one real evaluator dependency graph.

  This module orders descriptors by visible `provides`/`requires` dependencies
  and runs evaluators once per projection pass, caching their declared outputs
  by capability. It intentionally avoids registry, plugin, versioning, or
  sandbox concerns.
  """

  alias Improve.Planning.EvaluatorCapabilities

  @type diagnostic :: map()
  @type evaluator_name :: EvaluatorCapabilities.evaluator_name()
  @type descriptor :: EvaluatorCapabilities.descriptor()
  @type evaluator_result :: {:ok, map(), [diagnostic()]} | {:error, diagnostic()}
  @type evaluator_fun :: (map() -> evaluator_result())

  @type run_result :: %{
          required(:order) => [evaluator_name()],
          required(:outputs) => map(),
          required(:results) => %{evaluator_name() => map()},
          required(:diagnostics) => [diagnostic()]
        }

  @doc """
  Orders descriptors so providers run before consumers.

  Requirements that no descriptor provides are treated as host inputs.
  """
  @spec order([descriptor()]) :: {:ok, [descriptor()]} | {:error, diagnostic()}
  def order(descriptors) when is_list(descriptors) do
    with :ok <- ensure_unique_evaluators(descriptors),
         :ok <- ensure_single_provider_per_capability(descriptors) do
      dependencies = dependencies_by_evaluator(descriptors)
      order_descriptors(descriptors, dependencies, [])
    end
  end

  @doc """
  Runs descriptors in dependency order.

  `host_input` supplies ordinary projection inputs. Evaluator outputs are cached
  by declared capability and merged into downstream evaluator input.
  """
  @spec run([descriptor()], map(), %{evaluator_name() => evaluator_fun()}) ::
          {:ok, run_result()} | {:error, diagnostic()}
  def run(descriptors, host_input, evaluators)
      when is_list(descriptors) and is_map(host_input) and is_map(evaluators) do
    with {:ok, ordered} <- order(descriptors),
         :ok <- ensure_evaluator_functions(ordered, evaluators) do
      initial = %{order: [], outputs: %{}, results: %{}, diagnostics: []}

      Enum.reduce_while(ordered, {:ok, initial}, fn descriptor, {:ok, state} ->
        available_input = Map.merge(host_input, state.outputs)

        case input_for(descriptor, available_input) do
          {:ok, evaluator_input} ->
            run_evaluator(descriptor, evaluator_input, evaluators, state)

          {:error, diagnostic} ->
            {:halt, {:error, diagnostic}}
        end
      end)
    end
  end

  defp order_descriptors([], _dependencies, ordered) do
    {:ok, Enum.reverse(ordered)}
  end

  defp order_descriptors(remaining, dependencies, ordered) do
    case Enum.find(remaining, &(MapSet.size(Map.fetch!(dependencies, &1.evaluator)) == 0)) do
      nil ->
        {:error,
         diagnostic(
           :cyclic_evaluator_dependency,
           "Evaluator capabilities contain a cycle, so the host cannot order them.",
           %{remaining: Enum.map(remaining, & &1.evaluator)}
         )}

      descriptor ->
        remaining = List.delete(remaining, descriptor)

        dependencies =
          Map.new(dependencies, fn {evaluator, requires} ->
            {evaluator, MapSet.delete(requires, descriptor.evaluator)}
          end)

        order_descriptors(remaining, dependencies, [descriptor | ordered])
    end
  end

  defp dependencies_by_evaluator(descriptors) do
    providers = EvaluatorCapabilities.providers_by_capability(descriptors)

    Map.new(descriptors, fn descriptor ->
      dependencies =
        descriptor.requires
        |> Enum.flat_map(fn capability ->
          providers
          |> Map.get(capability, [])
          |> Enum.reject(&(&1.evaluator == descriptor.evaluator))
          |> Enum.map(& &1.evaluator)
        end)
        |> MapSet.new()

      {descriptor.evaluator, dependencies}
    end)
  end

  defp input_for(descriptor, available_input) do
    missing =
      descriptor.requires
      |> Enum.reject(&Map.has_key?(available_input, &1))

    if missing == [] do
      {:ok, Map.take(available_input, descriptor.requires)}
    else
      {:error,
       diagnostic(
         :missing_evaluator_input,
         "The host could not assemble required input for #{descriptor.evaluator}.",
         %{evaluator: descriptor.evaluator, missing: missing}
       )}
    end
  end

  defp run_evaluator(descriptor, evaluator_input, evaluators, state) do
    evaluator = Map.fetch!(evaluators, descriptor.evaluator)

    case evaluator.(evaluator_input) do
      {:ok, outputs, diagnostics} when is_map(outputs) and is_list(diagnostics) ->
        case output_for(descriptor, outputs) do
          {:ok, declared_outputs} ->
            state =
              state
              |> Map.update!(:order, &(&1 ++ [descriptor.evaluator]))
              |> Map.update!(:outputs, &Map.merge(&1, declared_outputs))
              |> Map.update!(:results, &Map.put(&1, descriptor.evaluator, outputs))
              |> Map.update!(:diagnostics, &(&1 ++ diagnostics))

            {:cont, {:ok, state}}

          {:error, diagnostic} ->
            {:halt, {:error, diagnostic}}
        end

      {:error, diagnostic} when is_map(diagnostic) ->
        {:halt, {:error, diagnostic}}

      other ->
        {:halt,
         {:error,
          diagnostic(
            :invalid_evaluator_result,
            "Evaluator #{descriptor.evaluator} returned an invalid result.",
            %{evaluator: descriptor.evaluator, result: inspect(other)}
          )}}
    end
  end

  defp output_for(descriptor, outputs) do
    missing =
      descriptor.provides
      |> Enum.reject(&Map.has_key?(outputs, &1))

    if missing == [] do
      {:ok, Map.take(outputs, descriptor.provides)}
    else
      {:error,
       diagnostic(
         :missing_evaluator_output,
         "Evaluator #{descriptor.evaluator} did not return its declared output.",
         %{evaluator: descriptor.evaluator, missing: missing}
       )}
    end
  end

  defp ensure_unique_evaluators(descriptors) do
    evaluators = Enum.map(descriptors, & &1.evaluator)
    duplicates = duplicates(evaluators)

    if duplicates == [] do
      :ok
    else
      {:error,
       diagnostic(
         :duplicate_evaluator_descriptor,
         "Evaluator capabilities include duplicate evaluator descriptors.",
         %{duplicates: duplicates}
       )}
    end
  end

  defp ensure_single_provider_per_capability(descriptors) do
    providers = EvaluatorCapabilities.providers_by_capability(descriptors)

    duplicates =
      providers
      |> Enum.filter(fn {_capability, descriptors} -> length(descriptors) > 1 end)
      |> Enum.map(fn {capability, descriptors} ->
        %{capability: capability, evaluators: Enum.map(descriptors, & &1.evaluator)}
      end)

    if duplicates == [] do
      :ok
    else
      {:error,
       diagnostic(
         :ambiguous_capability_provider,
         "A capability is provided by more than one evaluator, so the host cannot choose one.",
         %{duplicates: duplicates}
       )}
    end
  end

  defp ensure_evaluator_functions(descriptors, evaluators) do
    missing =
      descriptors
      |> Enum.map(& &1.evaluator)
      |> Enum.reject(&Map.has_key?(evaluators, &1))

    if missing == [] do
      :ok
    else
      {:error,
       diagnostic(
         :missing_evaluator_function,
         "The host has no function for one or more evaluator descriptors.",
         %{missing: missing}
       )}
    end
  end

  defp duplicates(values) do
    values
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(fn {value, _count} -> value end)
  end

  defp diagnostic(code, message, details) do
    %{severity: :error, code: code, message: message, details: details}
  end
end
