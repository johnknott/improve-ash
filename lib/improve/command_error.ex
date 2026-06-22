defmodule Improve.CommandError do
  @moduledoc """
  Structured exception for headless command workflow failures.

  The original cause is preserved for debugging while callers can assert stable
  categories such as `:invalid_command` or `:forbidden`.
  """

  defexception [:category, :operation, :details, :cause, :message]

  def raise!(operation, error) do
    raise exception(operation: operation, error: error)
  end

  def forbidden!(operation, details \\ ["Forbidden."]) do
    details = List.wrap(details)

    raise %__MODULE__{
      category: :forbidden,
      operation: operation,
      details: details,
      cause: nil,
      message: message(operation, :forbidden, details)
    }
  end

  def wrap!(operation, fun) when is_function(fun, 0) do
    fun.()
  rescue
    error in [__MODULE__] ->
      reraise error, __STACKTRACE__

    error ->
      raise!(operation, error)
  end

  @impl true
  def exception(opts) do
    operation = Keyword.fetch!(opts, :operation)
    error = Keyword.fetch!(opts, :error)
    category = category(error)
    details = details(error)

    %__MODULE__{
      category: category,
      operation: operation,
      details: details,
      cause: cause(error),
      message: message(operation, category, details)
    }
  end

  defp category(error) when is_list(error), do: :invalid_command

  defp category(%ArgumentError{}), do: :invalid_command

  defp category(error) do
    error
    |> inspect()
    |> then(fn inspected ->
      cond do
        String.contains?(inspected, "Forbidden") -> :forbidden
        String.contains?(inspected, "Invalid") -> :invalid_command
        true -> :command_failed
      end
    end)
  end

  defp details(error) when is_list(error), do: error
  defp details(%ArgumentError{message: message}), do: [message]
  defp details(error) when is_exception(error), do: [Exception.message(error)]
  defp details(error), do: [inspect(error)]

  defp cause(error) when is_list(error), do: nil
  defp cause(error), do: error

  defp message(operation, category, details) do
    "#{operation} failed with #{category}: #{Enum.join(details, " ")}"
  end
end
