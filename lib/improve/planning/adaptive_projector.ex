defmodule Improve.Planning.AdaptiveProjector do
  @moduledoc """
  Orchestrates projection with evaluator pipeline integration.

  When a plan has evaluator bundles configured, this module:
  1. Runs a first-pass projection (authored targets only)
  2. Builds evaluator input from the projection + plan context
  3. Runs the evaluator graph to produce derived adjustments
  4. Re-projects with effective targets applied
  5. Merges evaluator diagnostics and adaptation output into the final projection
  """

  alias Improve.Planning.BundleRegistry
  alias Improve.Planning.EvaluatorGraph
  alias Improve.Planning.ProgressionPosition
  alias Improve.Planning.Projector

  def project(input, bundle_keys) when bundle_keys == [] do
    Projector.project_today(input)
  end

  def project(input, bundle_keys) when is_list(bundle_keys) do
    {descriptors, bundle_diagnostics} = BundleRegistry.descriptors_for(bundle_keys)

    if descriptors == [] do
      projection = Projector.project_today(input)
      merge_diagnostics(projection, bundle_diagnostics)
    else
      project_with_evaluators(input, descriptors, bundle_keys, bundle_diagnostics)
    end
  end

  defp project_with_evaluators(input, descriptors, bundle_keys, bundle_diagnostics) do
    first_pass = Projector.project_today(input)

    evaluator_input = build_evaluator_input(input, first_pass)
    evaluators = BundleRegistry.evaluators_for(bundle_keys)

    {descriptors, evaluators} =
      maybe_add_progression_position(descriptors, evaluators, input)

    target_descriptors = Enum.filter(descriptors, &(&1.kind == :target_adjustment))
    target_deps = dependency_descriptors(target_descriptors, descriptors)
    target_graph = target_deps ++ target_descriptors

    case run_target_graph(target_graph, evaluator_input, evaluators) do
      {:ok, graph_result} ->
        adjustments = Map.get(graph_result.outputs, :derived_target_adjustments, %{})

        final_projection =
          if adjustments == %{} do
            first_pass
          else
            input
            |> Map.put(:derived_adjustments, adjustments)
            |> Projector.project_today()
          end

        final_projection
        |> merge_diagnostics(bundle_diagnostics ++ graph_result.diagnostics)
        |> Map.put(:evaluator_output, graph_result.outputs)
        |> Map.put(:adaptation, Map.get(graph_result.outputs, :marathon_adaptation))

      {:error, diagnostic} ->
        first_pass
        |> merge_diagnostics(bundle_diagnostics ++ [diagnostic])
    end
  end

  defp run_target_graph([], _input, _evaluators), do: {:ok, %{outputs: %{}, diagnostics: []}}

  defp run_target_graph(descriptors, input, evaluators) do
    relevant_evaluators = Map.take(evaluators, Enum.map(descriptors, & &1.evaluator))
    EvaluatorGraph.run(descriptors, input, relevant_evaluators)
  end

  defp dependency_descriptors(target_descriptors, all_descriptors) do
    required_caps =
      target_descriptors
      |> Enum.flat_map(& &1.requires)
      |> MapSet.new()

    all_descriptors
    |> Enum.filter(fn d ->
      d.kind != :target_adjustment and
        Enum.any?(d.provides, &MapSet.member?(required_caps, &1))
    end)
  end

  defp maybe_add_progression_position(descriptors, evaluators, input) do
    tracks = Map.get(input, :tracks, [])
    has_responsive = Enum.any?(tracks, &responsive_progression_track?/1)

    if has_responsive and not Enum.any?(descriptors, &(&1.evaluator == :progression_position)) do
      {
        [ProgressionPosition.descriptor() | descriptors],
        Map.put(evaluators, :progression_position, &ProgressionPosition.evaluate/1)
      }
    else
      {descriptors, evaluators}
    end
  end

  defp responsive_progression_track?(%{target: target}) when is_map(target) do
    type = Map.get(target, "type") || Map.get(target, :type)
    has_steps = Map.has_key?(target, "steps") or Map.has_key?(target, :steps)
    type == "responsive_progression" or (has_steps and type != "progression")
  end

  defp responsive_progression_track?(_), do: false

  defp build_evaluator_input(input, projection) do
    %{
      date: input.date,
      as_of_date: Map.get(input, :as_of_date, input.date),
      tracks: Map.get(input, :tracks, []),
      journal_events: Map.get(input, :journal_events, []),
      life_events: extract_life_events(input),
      time_off_windows: Map.get(input, :time_off_windows, []),
      timezone: Map.get(input, :timezone, "Etc/UTC"),
      projected_work: projection.projected_work,
      recent_missed_work: extract_recent_missed(projection),
      plan_skeleton: plan_skeleton(input),
      track_guidance: %{}
    }
  end

  defp extract_life_events(input) do
    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(&life_event?/1)
    |> Enum.map(&normalize_life_event/1)
  end

  defp life_event?(event) do
    event_type_key = Map.get(event, :event_type_key) || payload_type(event)
    event_type_key in [:illness, :injury, "illness", "injury"]
  end

  defp payload_type(event) do
    event
    |> Map.get(:payload, %{})
    |> Map.get("type", Map.get(Map.get(event, :payload, %{}), :type))
  end

  defp normalize_life_event(event) do
    payload = Map.get(event, :payload, %{})

    %{
      type: payload_type(event) |> to_atom(),
      from: map_date(payload, "starts_on") || map_date(payload, "from"),
      to: map_date(payload, "ends_on") || map_date(payload, "to"),
      symptoms: Map.get(payload, "symptoms") || Map.get(payload, :symptoms),
      severity: Map.get(payload, "severity") || Map.get(payload, :severity),
      area: Map.get(payload, "area") || Map.get(payload, :area),
      payload: payload
    }
  end

  defp to_atom(val) when is_atom(val), do: val
  defp to_atom("illness"), do: :illness
  defp to_atom("injury"), do: :injury
  defp to_atom(val) when is_binary(val), do: String.to_atom(val)
  defp to_atom(_), do: nil

  defp map_date(map, key) do
    case Map.get(map, key) do
      %Date{} = d -> d
      s when is_binary(s) -> Date.from_iso8601!(s)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp extract_recent_missed(projection) do
    Enum.filter(projection.projected_work, &(&1.status == :missed))
  end

  defp plan_skeleton(input) do
    plan = Map.get(input, :plan, %{})

    %{
      starts_on: Map.get(plan, :starts_on),
      ends_on: Map.get(plan, :ends_on),
      deadline: %{movable?: Map.get(plan, :ends_on) != nil}
    }
  end

  defp merge_diagnostics(projection, []), do: projection

  defp merge_diagnostics(projection, new_diagnostics) do
    Map.update!(projection, :diagnostics, &(&1 ++ new_diagnostics))
  end
end
