defmodule Improve.Validations.SamePlan do
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts) do
    opts =
      opts
      |> Keyword.put_new(:plan_id_attribute, :plan_id)
      |> Keyword.put_new(:references, [])
      |> Keyword.put_new(:array_references, [])

    {:ok, opts}
  end

  @impl true
  def validate(%Ash.Changeset{} = changeset, opts, _context) do
    plan_id = Ash.Changeset.get_attribute(changeset, opts[:plan_id_attribute])

    error =
      Enum.find_value(opts[:references], &reference_error(changeset, plan_id, &1)) ||
        Enum.find_value(opts[:array_references], &array_reference_error(changeset, plan_id, &1)) ||
        polymorphic_reference_error(changeset, plan_id, opts[:polymorphic_reference])

    case error do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp reference_error(changeset, plan_id, {field, resource}) do
    value = Ash.Changeset.get_attribute(changeset, field)

    if value && not belongs_to_plan?(resource, value, plan_id) do
      error(field)
    end
  end

  defp array_reference_error(changeset, plan_id, {field, resource}) do
    values = Ash.Changeset.get_attribute(changeset, field) || []

    if Enum.any?(values, &(not belongs_to_plan?(resource, &1, plan_id))) do
      error(field)
    end
  end

  defp polymorphic_reference_error(_changeset, _plan_id, nil), do: nil

  defp polymorphic_reference_error(changeset, plan_id, opts) do
    type = Ash.Changeset.get_attribute(changeset, Keyword.fetch!(opts, :type_field))
    id = Ash.Changeset.get_attribute(changeset, Keyword.fetch!(opts, :id_field))
    resource = Map.get(Keyword.fetch!(opts, :resources), type)

    cond do
      is_nil(id) ->
        nil

      is_nil(resource) ->
        error(Keyword.fetch!(opts, :id_field))

      not belongs_to_plan?(resource, id, plan_id) ->
        error(Keyword.fetch!(opts, :id_field))

      true ->
        nil
    end
  end

  defp belongs_to_plan?(_resource, _id, nil), do: false

  defp belongs_to_plan?(resource, id, plan_id) do
    resource
    |> Ash.Query.filter(id == ^id and plan_id == ^plan_id)
    |> Ash.exists?(authorize?: false)
  end

  defp error(field) do
    [field: field, message: "must belong to the same plan"]
  end
end
