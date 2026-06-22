defmodule Improve.Planning.ItemState do
  @moduledoc """
  Pure item state calculation from starting facts plus active item effects.

  This module deliberately does not read from the database or the clock. Callers
  pass explicit item facts and effects, and receive a value result.
  """

  alias Decimal, as: D

  defstruct item_id: nil,
            starting_facts: %{},
            active_effects: [],
            calculated_state: %{},
            warnings: []

  @quantity_effects ~w(add_quantity subtract_quantity set_quantity correction)a

  @type warning :: %{code: atom(), message: String.t(), details: map()}

  @type t :: %__MODULE__{
          item_id: term(),
          starting_facts: map(),
          active_effects: list(),
          calculated_state: map(),
          warnings: [warning()]
        }

  @doc """
  Calculates current item state from item facts and explicit effects.

  The first argument may be an Ash item struct/map with `:id` and `:facts`, or a
  facts map directly. Effects may be Ash item effect structs or plain maps.
  """
  @spec calculate(map(), [map()], keyword()) :: t()
  def calculate(item_or_facts, effects, opts \\ []) when is_list(effects) do
    item_id = field(item_or_facts, :id)
    starting_facts = facts_from(item_or_facts)
    starting_quantity = decimal_value(starting_facts, :starting_quantity)
    unit = value(starting_facts, :unit)

    active_effects = Enum.filter(effects, &active?/1)

    {quantity, calculated_facts, effect_warnings} =
      Enum.reduce(active_effects, {starting_quantity, starting_facts, []}, fn effect,
                                                                              {quantity, facts,
                                                                               warnings} ->
        apply_effect(effect, quantity, unit, facts, warnings)
      end)

    state =
      calculated_facts
      |> Map.put(:current_quantity, quantity)
      |> Map.put(:unit, unit)

    warnings =
      effect_warnings
      |> maybe_warn_missing_quantity(starting_quantity)
      |> maybe_warn_low_quantity(
        quantity,
        decimal_value(starting_facts, :low_quantity_threshold),
        unit
      )
      |> maybe_warn_future_quantity(quantity, decimal_opt(opts[:future_quantity_required]), unit)
      |> Enum.reverse()

    %__MODULE__{
      item_id: item_id,
      starting_facts: starting_facts,
      active_effects: active_effects,
      calculated_state: state,
      warnings: warnings
    }
  end

  defp facts_from(%{facts: facts}) when is_map(facts), do: atomize_keys(facts)
  defp facts_from(facts) when is_map(facts), do: atomize_keys(facts)

  defp apply_effect(effect, quantity, unit, facts, warnings) do
    effect_type = effect_type(effect)

    cond do
      effect_type in @quantity_effects ->
        apply_quantity_effect(effect_type, effect, quantity, unit, facts, warnings)

      effect_type == :set_fact ->
        {quantity, Map.merge(facts, atomize_keys(value(effect, :payload) || %{})), warnings}

      true ->
        {quantity, facts,
         [
           warning(:unsupported_effect, "Unsupported item effect was ignored.", %{
             effect_type: effect_type
           })
           | warnings
         ]}
    end
  end

  defp apply_quantity_effect(_effect_type, effect, nil, _unit, facts, warnings) do
    {nil, facts,
     [
       warning(
         :missing_starting_quantity,
         "Quantity effect was ignored because the item has no starting quantity.",
         %{effect_id: field(effect, :id)}
       )
       | warnings
     ]}
  end

  defp apply_quantity_effect(effect_type, effect, quantity, unit, facts, warnings) do
    effect_quantity = decimal_value(effect, :quantity)
    effect_unit = value(effect, :unit)

    cond do
      is_nil(effect_quantity) ->
        {quantity, facts,
         [
           warning(
             :missing_effect_quantity,
             "Quantity effect was ignored because it has no quantity.",
             %{effect_type: effect_type}
           )
           | warnings
         ]}

      unit_mismatch?(unit, effect_unit) ->
        {quantity, facts,
         [
           warning(
             :unit_mismatch,
             "Quantity effect was ignored because its unit does not match the item unit.",
             %{expected_unit: unit, actual_unit: effect_unit}
           )
           | warnings
         ]}

      effect_type == :add_quantity ->
        {D.add(quantity, effect_quantity), facts, warnings}

      effect_type == :subtract_quantity ->
        {D.sub(quantity, effect_quantity), facts, warnings}

      effect_type in [:set_quantity, :correction] ->
        {effect_quantity, facts, warnings}
    end
  end

  defp active?(effect), do: normalize_atom(value(effect, :status) || :active) == :active

  defp effect_type(effect), do: normalize_atom(value(effect, :effect_type))

  defp decimal_value(source, key), do: source |> value(key) |> decimal_opt()

  defp decimal_opt(nil), do: nil
  defp decimal_opt(%D{} = value), do: value
  defp decimal_opt(value) when is_integer(value), do: D.new(value)
  defp decimal_opt(value) when is_float(value), do: D.from_float(value)

  defp decimal_opt(value) when is_binary(value) do
    D.new(value)
  rescue
    D.Error -> nil
  end

  defp value(source, key) do
    field(source, key) || field(source, Atom.to_string(key))
  end

  defp field(source, key) when is_map(source), do: Map.get(source, key)
  defp field(_source, _key), do: nil

  defp atomize_keys(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      pair -> pair
    end)
  rescue
    ArgumentError ->
      map
  end

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp normalize_atom(_value), do: nil

  defp unit_mismatch?(nil, _effect_unit), do: false
  defp unit_mismatch?(_unit, nil), do: false
  defp unit_mismatch?(unit, effect_unit), do: unit != effect_unit

  defp maybe_warn_missing_quantity(warnings, nil) do
    [
      warning(
        :missing_starting_quantity,
        "Item has no starting quantity, so quantity state could not be calculated.",
        %{}
      )
      | warnings
    ]
  end

  defp maybe_warn_missing_quantity(warnings, _quantity), do: warnings

  defp maybe_warn_low_quantity(warnings, quantity, threshold, _unit)
       when is_nil(quantity) or is_nil(threshold) do
    warnings
  end

  defp maybe_warn_low_quantity(warnings, quantity, threshold, unit) do
    if D.compare(quantity, threshold) == :lt do
      [
        warning(:low_quantity, "Item quantity is below the configured low quantity threshold.", %{
          current_quantity: quantity,
          threshold: threshold,
          unit: unit
        })
        | warnings
      ]
    else
      warnings
    end
  end

  defp maybe_warn_future_quantity(warnings, quantity, required, _unit)
       when is_nil(quantity) or is_nil(required) do
    warnings
  end

  defp maybe_warn_future_quantity(warnings, quantity, required, unit) do
    if D.compare(quantity, required) == :lt do
      [
        warning(
          :insufficient_future_quantity,
          "Item quantity is insufficient for the requested future quantity.",
          %{current_quantity: quantity, required_quantity: required, unit: unit}
        )
        | warnings
      ]
    else
      warnings
    end
  end

  defp warning(code, message, details), do: %{code: code, message: message, details: details}
end
