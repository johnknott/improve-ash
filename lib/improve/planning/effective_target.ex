defmodule Improve.Planning.EffectiveTarget do
  @moduledoc """
  The target actually in force for a track on a given date.

  An effective target wraps the authored target with an optional derived
  adjustment. Completion and streaks evaluate against the effective value,
  not the raw authored target.
  """

  defstruct [
    :authored,
    :effective,
    :source,
    :reason,
    adjusted?: false
  ]

  @type t :: %__MODULE__{
          authored: map(),
          effective: map(),
          source: atom() | String.t() | nil,
          reason: String.t() | nil,
          adjusted?: boolean()
        }

  @doc """
  Builds an unadjusted effective target (effective == authored).
  """
  def from_authored(target) when is_map(target) do
    %__MODULE__{
      authored: target,
      effective: target,
      source: nil,
      reason: nil,
      adjusted?: false
    }
  end

  @doc """
  Applies a derived adjustment to an effective target.

  The adjustment map is merged into the authored target to produce the
  effective target. Only keys present in the adjustment override the
  authored values.
  """
  def adjust(%__MODULE__{authored: authored} = et, adjustment, opts \\ []) do
    effective = Map.merge(authored, adjustment)

    %__MODULE__{
      et
      | effective: effective,
        source: Keyword.get(opts, :source),
        reason: Keyword.get(opts, :reason),
        adjusted?: true
    }
  end

  @doc """
  Returns the target map that completion should evaluate against.
  """
  def target_for_completion(%__MODULE__{effective: effective}), do: effective

  @doc """
  Serializes for snapshot storage on events.
  """
  def to_snapshot(%__MODULE__{} = et) do
    snapshot = %{
      "authored" => et.authored,
      "effective" => et.effective,
      "adjusted" => et.adjusted?
    }

    snapshot
    |> maybe_put("source", et.source)
    |> maybe_put("reason", et.reason)
  end

  defp maybe_put(map, _key, nil), do: map

  defp maybe_put(map, key, value) when is_atom(value),
    do: Map.put(map, key, Atom.to_string(value))

  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
