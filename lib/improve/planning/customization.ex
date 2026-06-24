defmodule Improve.Planning.Customization do
  @moduledoc """
  Pure derivation of named values from a plan baseline.

  This is the hermetic core of Layer 2 customization: it takes an explicit
  baseline payload and a recipe, and returns named derived outputs. It does not
  read from the database, the clock, AI, or HTTP. Callers pass the baseline in
  and receive the derived values out.

  The marathon pace recipe is the first derivation kind. A recipe maps each
  output name to an entry of the form:

      {:secs_per_km, baseline_field, plus: seconds | minus: seconds}

  The baseline field names a timed-distance baseline (for example `:five_k`).
  Its secs-per-km is resolved from the baseline payload and the offset is
  applied to produce the output pace. Results are whole seconds per kilometer
  with a display label.
  """

  @type baseline :: map()
  @type recipe :: %{atom() => recipe_entry()}
  @type recipe_entry :: {:secs_per_km, atom(), keyword()}
  @type pace :: %{secs_per_km: non_neg_integer(), label: String.t()}
  @type outputs :: %{atom() => pace()}
  @type diagnostic :: %{output: atom() | nil, message: String.t(), details: map()}

  @spec derive(baseline(), recipe()) :: {:ok, outputs()} | {:error, [diagnostic()]}
  def derive(baseline, recipe) when is_map(recipe) do
    recipe
    # Preserve declaration order for readable diagnostics.
    |> Enum.reduce({%{}, []}, fn {output, entry}, {acc, errors} ->
      case derive_entry(entry, baseline) do
        {:ok, pace} -> {Map.put(acc, output, pace), errors}
        {:error, diagnostic} -> {acc, [%{diagnostic | output: output} | errors]}
      end
    end)
    |> case do
      {outputs, []} -> {:ok, outputs}
      {_outputs, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp derive_entry({:secs_per_km, field, offset}, baseline) when is_list(offset) do
    with {:ok, base} <- resolve_field(field, baseline),
         {:ok, adjusted} <- apply_offset(base, offset) do
      {:ok, %{secs_per_km: adjusted, label: label_pace(adjusted)}}
    end
  end

  defp derive_entry({:secs_per_km, _field, offset}, _baseline) do
    {:error,
     diagnostic("Recipe offset must be a keyword list, such as plus: 75 or minus: 5.",
       offset: offset
     )}
  end

  defp derive_entry(entry, _baseline) do
    {:error,
     diagnostic("Unsupported recipe entry; expected {:secs_per_km, field, plus: n | minus: n}.",
       entry: entry
     )}
  end

  defp resolve_field(field, baseline) do
    with {:ok, expected_distance} <- expected_distance(field) do
      distance = value(baseline, :distance_km)
      duration = duration_seconds(baseline)

      cond do
        not (is_number(distance) and is_number(duration) and distance > 0) ->
          {:error,
           diagnostic(
             "Baseline field #{inspect(field)} could not be resolved: the baseline needs distance_km and minutes.",
             field: field,
             baseline: baseline
           )}

        distance != expected_distance ->
          {:error,
           diagnostic(
             "Baseline field #{inspect(field)} needs a #{expected_distance} km baseline, but the payload has #{distance} km.",
             field: field,
             expected_distance_km: expected_distance,
             actual_distance_km: distance
           )}

        true ->
          {:ok, round(duration / distance)}
      end
    end
  end

  defp expected_distance(:five_k), do: {:ok, 5}
  defp expected_distance("five_k"), do: {:ok, 5}
  defp expected_distance(:ten_k), do: {:ok, 10}
  defp expected_distance("ten_k"), do: {:ok, 10}

  defp expected_distance(field) do
    {:error,
     diagnostic(
       "Baseline field #{inspect(field)} is not supported. Supported fields are :five_k and :ten_k.",
       field: field
     )}
  end

  defp duration_seconds(baseline) do
    minutes = value(baseline, :minutes)
    seconds = value(baseline, :seconds) || 0
    duration_secs = value(baseline, :duration_secs)

    cond do
      is_number(minutes) ->
        minutes * 60 + seconds

      is_number(duration_secs) ->
        duration_secs

      true ->
        nil
    end
  end

  defp apply_offset(base, offset) when is_list(offset) do
    plus? = Keyword.has_key?(offset, :plus)
    minus? = Keyword.has_key?(offset, :minus)

    cond do
      plus? and minus? ->
        {:error,
         diagnostic("Recipe offset should use either plus or minus, not both.",
           offset: offset
         )}

      plus? ->
        apply_numeric_offset(base, :plus, offset[:plus])

      minus? ->
        apply_numeric_offset(base, :minus, offset[:minus])

      true ->
        {:ok, base}
    end
  end

  defp apply_numeric_offset(base, :plus, value) when is_number(value),
    do: {:ok, round(base + value)}

  defp apply_numeric_offset(base, :minus, value) when is_number(value),
    do: {:ok, round(base - value)}

  defp apply_numeric_offset(_base, key, value) do
    {:error,
     diagnostic("Recipe offset #{inspect(key)} must be a number.",
       offset: %{key => value}
     )}
  end

  defp label_pace(secs_per_km) do
    minutes = div(secs_per_km, 60)
    seconds = rem(secs_per_km, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}/km"
  end

  defp value(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, Atom.to_string(key)) do
      value when is_number(value) -> value
      _ -> nil
    end
  end

  defp diagnostic(message, details),
    do: %{output: nil, message: message, details: Map.new(details)}
end
