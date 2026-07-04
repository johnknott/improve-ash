defmodule Improve.Planning.BundleRegistry do
  @moduledoc """
  Maps plan evaluator bundle keys to their descriptor sets and evaluator functions.

  The registry is the only place that connects string bundle keys (stored on plans)
  to code modules. Adding a new bundle means registering it here.
  """

  alias Improve.Bundles.Marathon
  alias Improve.Bundles.Strength

  @bundles %{
    "marathon" => %{
      descriptors: &Marathon.evaluator_descriptors/0,
      evaluators: %{
        recent_load_metric: &Improve.Bundles.Marathon.RecentLoad.evaluate/1,
        marathon_target_adjustment: &Improve.Bundles.Marathon.TargetAdjustment.evaluate/1,
        marathon_adaptation: &Improve.Bundles.Marathon.Adaptation.evaluate/1
      }
    },
    "strength" => %{
      descriptors: &Strength.evaluator_descriptors/0,
      evaluators: %{
        strength_fatigue: &Improve.Bundles.Strength.Fatigue.evaluate/1,
        strength_adaptation: &Improve.Bundles.Strength.Adaptation.evaluate/1
      }
    }
  }

  @doc """
  Returns the combined descriptors for a list of bundle keys.
  Unknown keys are skipped with a diagnostic.
  """
  def descriptors_for(bundle_keys) when is_list(bundle_keys) do
    {descriptors, diagnostics} =
      Enum.reduce(bundle_keys, {[], []}, fn key, {descs, diags} ->
        case Map.get(@bundles, key) do
          nil ->
            {descs, diags ++ [unknown_bundle_diagnostic(key)]}

          bundle ->
            {descs ++ bundle.descriptors.(), diags}
        end
      end)

    {descriptors, diagnostics}
  end

  @doc """
  Returns the combined evaluator function map for a list of bundle keys.
  """
  def evaluators_for(bundle_keys) when is_list(bundle_keys) do
    Enum.reduce(bundle_keys, %{}, fn key, acc ->
      case Map.get(@bundles, key) do
        nil -> acc
        bundle -> Map.merge(acc, bundle.evaluators)
      end
    end)
  end

  @doc """
  Lists all known bundle keys.
  """
  def known_keys, do: Map.keys(@bundles)

  defp unknown_bundle_diagnostic(key) do
    %{
      code: :unknown_evaluator_bundle,
      severity: :warning,
      message: "Evaluator bundle \"#{key}\" is not recognized and will be skipped.",
      details: %{bundle_key: key}
    }
  end
end
