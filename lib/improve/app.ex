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
  alias Improve.App.Customize
  alias Improve.App.Effects
  alias Improve.App.Logging
  alias Improve.App.Review
  alias Improve.App.Schedule
  alias Improve.App.Session
  alias Improve.App.State
  alias Improve.App.Target
  alias Improve.App.Today

  defdelegate create_plan!(name, opts), to: Authoring
  defdelegate add_event_type!(plan, name, opts), to: Authoring
  defdelegate add_item_type!(plan, name, opts), to: Authoring
  defdelegate add_item!(plan, name, opts), to: Authoring
  defdelegate add_pool!(plan, name, opts), to: Authoring
  defdelegate add_track!(plan, name, opts), to: Authoring
  defdelegate add_session!(plan, name, opts), to: Authoring
  defdelegate add_time_off!(plan, opts), to: Authoring
  defdelegate customize_plan!(plan, opts), to: Customize

  defdelegate every_day(), to: Schedule
  defdelegate selected_weekdays(days), to: Schedule
  defdelegate every_n_days(days), to: Schedule
  defdelegate times_per_week(times), to: Schedule
  defdelegate times_per_week(times, opts), to: Schedule
  defdelegate every_week(opts), to: Schedule
  defdelegate every_n_weeks(weeks, opts), to: Schedule
  defdelegate monthly(opts), to: Schedule
  defdelegate after_completion(opts), to: Schedule
  defdelegate custom(description), to: Schedule
  defdelegate choose(count, opts), to: Session
  defdelegate subtract_quantity(opts), to: Effects
  defdelegate add_quantity(opts), to: Effects
  defdelegate set_quantity(opts), to: Effects
  defdelegate fixed(quantity, unit), to: Target
  defdelegate fixed(quantity, unit, opts), to: Target
  defdelegate metric(name), to: Target
  defdelegate metric(name, opts), to: Target
  defdelegate checklist(items), to: Target
  defdelegate period_total(quantity, unit, opts), to: Target
  defdelegate progression(opts), to: Target
  defdelegate progression(from, to, opts), to: Target
  defdelegate adaptive(opts), to: Target
  defdelegate number(unit), to: Target
  defdelegate number(unit, opts), to: Target
  defdelegate amount(unit), to: Target
  defdelegate amount(unit, opts), to: Target
  defdelegate fields(fields), to: Target

  defdelegate project_today!(plan, opts), to: Today

  defdelegate start_session!(projection, session_key, opts), to: Logging
  defdelegate log_session_slot!(started_session, opts), to: Logging
  defdelegate skip_session_slot!(started_session, opts), to: Logging
  defdelegate log_event!(plan, opts), to: Logging
  defdelegate log_track!(projection, opts), to: Logging
  defdelegate correct_event!(original_log_or_event, opts), to: Logging
  defdelegate build_offline_event(plan, opts), to: Logging
  defdelegate submit_offline_events!(entries, opts), to: Logging

  def offline_event(plan, opts), do: build_offline_event(plan, opts)

  defdelegate get_item_state!(plan, item_key, opts), to: State

  defdelegate review!(plan, opts), to: Review

  defdelegate get_ai_plan_summary!(plan, opts), to: AiContext
  defdelegate get_ai_today_context!(plan, opts), to: AiContext
  defdelegate get_ai_recent_journal!(plan, opts), to: AiContext
  defdelegate get_ai_item_state!(plan, item_key, opts), to: AiContext
end
