defmodule Improve.App do
  @moduledoc """
  Product-facing application API.

  `Improve.App` is the stable facade for operations a UI, story script, RPC
  layer, or assistant orchestration flow would naturally call. It delegates
  persistence, validation, projection, journal writes, effects, state
  derivation, and AI reads to the lower domains and plain Elixir modules.
  """

  alias Improve.App.AiContext
  alias Improve.App.Authoring
  alias Improve.App.Effects
  alias Improve.App.Logging
  alias Improve.App.Schedule
  alias Improve.App.Session
  alias Improve.App.State
  alias Improve.App.Today

  defdelegate create_plan!(name, opts), to: Authoring
  defdelegate add_event_type!(plan, name, opts), to: Authoring
  defdelegate add_item_type!(plan, name, opts), to: Authoring
  defdelegate add_item!(plan, name, opts), to: Authoring
  defdelegate add_pool!(plan, name, opts), to: Authoring
  defdelegate add_direct_goal!(plan, name, opts), to: Authoring
  defdelegate add_session!(plan, name, opts), to: Authoring

  defdelegate every_day(), to: Schedule
  defdelegate every_week(opts), to: Schedule
  defdelegate choose(count, opts), to: Session
  defdelegate subtract_quantity(opts), to: Effects

  defdelegate project_today!(plan, opts), to: Today

  defdelegate start_session!(projection, session_key, opts), to: Logging
  defdelegate log_session_slot!(started_session, opts), to: Logging
  defdelegate log_event!(plan, opts), to: Logging
  defdelegate log_direct_goal!(projection, opts), to: Logging
  defdelegate correct_event!(original_log_or_event, opts), to: Logging
  defdelegate build_offline_event(plan, opts), to: Logging
  defdelegate submit_offline_events!(entries, opts), to: Logging

  def offline_event(plan, opts), do: build_offline_event(plan, opts)

  defdelegate get_item_state!(plan, item_key, opts), to: State

  defdelegate get_ai_plan_summary!(plan, opts), to: AiContext
  defdelegate get_ai_today_context!(plan, opts), to: AiContext
  defdelegate get_ai_recent_journal!(plan, opts), to: AiContext
  defdelegate get_ai_item_state!(plan, item_key, opts), to: AiContext
end
