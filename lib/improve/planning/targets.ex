defmodule Improve.Planning.Targets do
  @moduledoc """
  Internal target projection diagnostic dispatcher.

  This keeps target support tiers out of the main projector while preserving the
  current product-facing diagnostics.
  """

  alias Improve.Planning.Targets.Evaluation

  @implemented_evaluators [
    Improve.Planning.Targets.Fixed
  ]

  @implemented Map.new(@implemented_evaluators, &{&1.target_type(), &1})
  @recognized_unsupported ~w(metric checklist period_total progression adaptive)

  @type diagnostic :: map()
  @type result :: [diagnostic()]
  @type target_support ::
          :missing
          | :implicit
          | {:implemented, module()}
          | {:recognized_unsupported, String.t()}
          | {:unknown, String.t()}

  @spec diagnostics(map()) :: result()
  def diagnostics(track) do
    case target_support(track) do
      :missing ->
        [missing_target_diagnostic(track)]

      :implicit ->
        []

      {:implemented, evaluator} ->
        evaluator.diagnostics(%Evaluation{track: track})

      {:recognized_unsupported, type} ->
        [recognized_unsupported_diagnostic(track, type)]

      {:unknown, type} ->
        [unknown_diagnostic(track, type)]
    end
  end

  @spec target_support(map()) :: target_support()
  def target_support(%{target: nil}), do: :missing

  def target_support(%{target: target}) when is_map(target) and map_size(target) == 0 do
    :missing
  end

  def target_support(%{target: target}) when is_map(target) do
    case target_type(target) do
      nil ->
        :implicit

      type ->
        support(type)
    end
  end

  def target_support(_track), do: :implicit

  @spec support(String.t()) ::
          {:implemented, module()}
          | {:recognized_unsupported, String.t()}
          | {:unknown, String.t()}
  def support(type) do
    cond do
      Map.has_key?(@implemented, type) -> {:implemented, Map.fetch!(@implemented, type)}
      type in @recognized_unsupported -> {:recognized_unsupported, type}
      true -> {:unknown, type}
    end
  end

  defp target_type(target) do
    case Map.get(target, "type") || Map.get(target, :type) do
      nil -> nil
      type when is_atom(type) -> Atom.to_string(type)
      type when is_binary(type) -> type
    end
  end

  defp missing_target_diagnostic(track) do
    %{
      code: :missing_track_target,
      severity: :warning,
      message:
        "Track has no target, so completion can only be inferred from linked journal events.",
      details: %{track_id: track.id, track_key: track.key}
    }
  end

  defp recognized_unsupported_diagnostic(track, type) do
    %{
      code: :unsupported_track_target_type,
      severity: :info,
      message:
        "This track target type is recognized, but projection support is not implemented yet.",
      details: %{track_id: track.id, track_key: track.key, target_type: type}
    }
  end

  defp unknown_diagnostic(track, type) do
    %{
      code: :unknown_track_target_type,
      severity: :warning,
      message: "This track target type is not recognized.",
      details: %{track_id: track.id, track_key: track.key, target_type: type}
    }
  end
end
