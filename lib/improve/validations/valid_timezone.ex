defmodule Improve.Validations.ValidTimezone do
  @moduledoc """
  Validates that an attribute holds a known IANA time zone identifier.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, Keyword.put_new(opts, :attribute, :timezone)}
  end

  @impl true
  def atomic(changeset, opts, context) do
    validate(changeset, opts, context)
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)

    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil ->
        :ok

      timezone ->
        case DateTime.shift_zone(DateTime.utc_now(), timezone) do
          {:ok, _shifted} ->
            :ok

          {:error, _reason} ->
            {:error, field: attribute, message: "must be a valid time zone, like Europe/London"}
        end
    end
  end
end
