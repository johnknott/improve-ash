defmodule Improve.Fixtures.ImproveMyselfPlan do
  @moduledoc """
  Installs the "Improve myself!" plan — a real plan exported from the previous
  Improve app — as realistic, track-heavy local demo data.

  Translation follows the story 09 mapping
  (`priv/scripts/stories/09_full_life_plan.exs`): strength and cardio warm-up
  tracks become two gym sessions with pools; metrics, habits, checklists,
  progressions and the vial dose stay as tracks; the Retatrutide vial is a
  stateful item with a subtract-on-dose effect. Source export:
  `priv/drafts/improve-myself.plan-draft-v1.json`.
  """

  alias Improve.App
  alias Improve.Plans

  @source_key "improve_myself_v1"

  def source_key, do: @source_key

  @doc """
  Installs the plan for `user` and returns it. Callers guard against
  re-installation with `source_key/0`.
  """
  def install!(user, opts \\ []) do
    actor = user
    starts_on = Keyword.get(opts, :starts_on, ~D[2026-06-16])
    ends_on = Keyword.get(opts, :ends_on, ~D[2026-08-06])

    plan =
      Plans.create_plan!(
        %{
          name: "Improve myself!",
          intention: "Improve my fitness and mental health",
          starts_on: starts_on,
          ends_on: ends_on,
          status: :active,
          source_kind: :imported,
          source_key: @source_key
        },
        actor: actor
      )

    install_event_types!(plan, actor)
    install_vial_inventory!(plan, actor)
    install_body_metrics!(plan, actor)
    install_movement_and_cardio!(plan, actor)
    install_strength_sessions!(plan, actor)
    install_foundations!(plan, actor)
    install_health!(plan, actor)
    install_home!(plan, actor)
    install_recovery!(plan, actor)

    plan
  end

  defp install_event_types!(plan, actor) do
    App.add_event_type!(plan, "Metric logged",
      actor: actor,
      key: "metric_logged",
      description: "A body measurement reading.",
      payload: %{
        required: ["value", "unit"],
        properties: %{value: %{type: "number"}, unit: %{type: "string"}, note: %{type: "string"}}
      }
    )

    App.add_event_type!(plan, "Quantity logged",
      actor: actor,
      key: "quantity_logged",
      description: "An amount of something done.",
      payload: %{
        required: ["amount", "unit"],
        properties: %{amount: %{type: "number"}, unit: %{type: "string"}, note: %{type: "string"}}
      }
    )

    App.add_event_type!(plan, "Checklist completed",
      actor: actor,
      key: "checklist_completed",
      description: "Ticked-off checklist items.",
      payload: %{
        required: ["completed_items"],
        properties: %{completed_items: %{type: "array"}, note: %{type: "string"}}
      }
    )

    App.add_event_type!(plan, "Exercise performed",
      actor: actor,
      key: "exercise_performed",
      description: "A strength exercise set.",
      required_links: ["exercise"],
      payload: %{
        required: ["sets", "reps"],
        properties: %{
          sets: %{type: "integer"},
          reps: %{type: "string"},
          load: %{type: "number"},
          load_unit: %{type: "string"},
          machine_used: %{type: "string"},
          effort: %{type: "string"},
          note: %{type: "string"}
        }
      }
    )

    App.add_event_type!(plan, "Cardio performed",
      actor: actor,
      key: "cardio_performed",
      description: "A cardio block.",
      required_links: ["activity"],
      payload: %{
        required: ["amount", "unit"],
        properties: %{
          amount: %{type: "number"},
          unit: %{type: "string"},
          duration: %{type: "string"},
          distance_km: %{type: "number"},
          effort: %{type: "string"},
          note: %{type: "string"}
        }
      }
    )
  end

  defp install_vial_inventory!(plan, actor) do
    App.add_item_type!(plan, "Peptide vial",
      actor: actor,
      key: "peptide_vial",
      description: "A small container with contents and a tracked remaining amount.",
      display_hints: %{kind: "inventory"}
    )

    App.add_item!(plan, "Retatrutide",
      actor: actor,
      key: "retatrutide",
      type: "peptide_vial",
      stateful: true,
      facts: %{
        starting_quantity: 20,
        unit: "mg",
        prepared_volume_ml: 20,
        contents: "Retatrutide"
      }
    )

    App.add_event_type!(plan, "Dose taken",
      actor: actor,
      key: "dose_taken",
      description: "A dose drawn from a vial; the remaining amount is tracked automatically.",
      required_links: ["source_vial"],
      payload: %{
        required: ["amount", "unit"],
        properties: %{
          amount: %{type: "number"},
          unit: %{type: "string"},
          site: %{type: "string"},
          note: %{type: "string"}
        }
      },
      effects: [
        App.subtract_quantity(from: "source_vial", quantity: "payload.amount", unit: "payload.unit")
      ]
    )
  end

  defp install_body_metrics!(plan, actor) do
    App.add_track!(plan, "Weigh myself",
      actor: actor,
      key: "weigh_myself",
      event: "metric_logged",
      description:
        "Daily bodyweight check-in. Log the number only; judge progress by the weekly trend rather than day-to-day noise.",
      schedule: App.every_day(),
      target: %{
        unit: "kg",
        quantity_path: "payload.value",
        summary_template: "Logged weight: %{quantity} %{unit}"
      }
    )

    App.add_track!(plan, "Measure waist",
      actor: actor,
      key: "measure_waist",
      event: "metric_logged",
      description:
        "Weekly waist measurement. Take it consistently on Tuesday, ideally at the same time of day.",
      schedule: App.every_week(times: 1, on: [:tuesday]),
      target: %{
        unit: "cm",
        quantity_path: "payload.value",
        summary_template: "Logged waist: %{quantity} %{unit}"
      }
    )
  end

  defp install_movement_and_cardio!(plan, actor) do
    App.add_track!(plan, "Steps",
      actor: actor,
      key: "steps",
      event: "quantity_logged",
      description:
        "Baseline daily movement target. Treat gym and cycling as extra unless you need a recovery day.",
      schedule: App.every_day(),
      target: %{
        quantity: 10_000,
        unit: "steps",
        quantity_path: "payload.amount",
        summary_template: "Logged %{quantity} %{unit}",
        progression: %{from: 1_000, to: 10_000, shape: "linear"}
      }
    )

    App.add_item_type!(plan, "Cardio activity", actor: actor, key: "cardio_activity")
    App.add_item!(plan, "Cycling", actor: actor, key: "cycling", type: "cardio_activity")
    App.add_item!(plan, "Rowing", actor: actor, key: "rowing", type: "cardio_activity")
    App.add_item!(plan, "Elliptical", actor: actor, key: "elliptical", type: "cardio_activity")

    App.add_track!(plan, "Cycling",
      actor: actor,
      key: "cycling",
      event: "cardio_performed",
      description:
        "Steady bike session. Log distance in km and keep the effort moderate enough to recover for gym days.",
      schedule: App.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
      target: %{
        quantity: 60,
        unit: "min",
        quantity_path: "payload.amount",
        summary_template: "Completed %{quantity} %{unit} cycling",
        progression: %{from: 20, to: 60, shape: "linear"},
        default_links: %{activity: "cycling"}
      }
    )
  end

  defp install_strength_sessions!(plan, actor) do
    App.add_item_type!(plan, "Exercise", actor: actor, key: "exercise")

    App.add_item!(plan, "Chest Press", actor: actor, key: "chest_press", type: "exercise")
    App.add_item!(plan, "Lat Pulldown", actor: actor, key: "lat_pulldown", type: "exercise")
    App.add_item!(plan, "Shoulder Press", actor: actor, key: "shoulder_press", type: "exercise")
    App.add_item!(plan, "Leg Press", actor: actor, key: "leg_press", type: "exercise")
    App.add_item!(plan, "Leg Curl", actor: actor, key: "leg_curl", type: "exercise")
    App.add_item!(plan, "Leg Extension", actor: actor, key: "leg_extension", type: "exercise")

    App.add_pool!(plan, "Upper cardio warm-up",
      actor: actor,
      key: "upper_cardio",
      items: ["rowing", "elliptical"]
    )

    App.add_pool!(plan, "Upper body push", actor: actor, key: "upper_push", items: ["chest_press"])
    App.add_pool!(plan, "Upper body pull", actor: actor, key: "upper_pull", items: ["lat_pulldown"])

    App.add_pool!(plan, "Upper body shoulders",
      actor: actor,
      key: "upper_shoulders",
      items: ["shoulder_press"]
    )

    App.add_pool!(plan, "Lower cardio warm-up",
      actor: actor,
      key: "lower_cardio",
      items: ["rowing", "elliptical"]
    )

    App.add_pool!(plan, "Lower body press", actor: actor, key: "lower_press", items: ["leg_press"])

    App.add_pool!(plan, "Lower body hamstrings",
      actor: actor,
      key: "lower_hamstrings",
      items: ["leg_curl"]
    )

    App.add_pool!(plan, "Lower body quads",
      actor: actor,
      key: "lower_quads",
      items: ["leg_extension"]
    )

    App.add_session!(plan, "Upper body gym visit",
      actor: actor,
      key: "upper_body_gym",
      description: "Warm-up cardio then push, pull, and shoulder patterns at medium effort.",
      schedule: App.every_week(times: 2, on: [:tuesday, :thursday]),
      defaults: %{
        event: "exercise_performed",
        payload: %{sets: 2, reps: "8", effort: "medium"}
      },
      slots: [
        App.choose(2, from: "upper_cardio", key: "upper_cardio", name: "Warm-up cardio"),
        App.choose(1, from: "upper_push", key: "upper_push", name: "Push pattern"),
        App.choose(1, from: "upper_pull", key: "upper_pull", name: "Pull pattern"),
        App.choose(1, from: "upper_shoulders", key: "upper_shoulders", name: "Shoulder pattern")
      ]
    )

    App.add_session!(plan, "Lower body gym visit",
      actor: actor,
      key: "lower_body_gym",
      description: "Warm-up cardio then press, hamstring, and quad patterns at medium effort.",
      schedule: App.every_week(times: 1, on: [:saturday]),
      defaults: %{
        event: "exercise_performed",
        payload: %{sets: 2, reps: "8-10", effort: "medium"}
      },
      slots: [
        App.choose(2, from: "lower_cardio", key: "lower_cardio", name: "Warm-up cardio"),
        App.choose(1, from: "lower_press", key: "lower_press", name: "Press pattern"),
        App.choose(1, from: "lower_hamstrings", key: "lower_hamstrings", name: "Hamstring pattern"),
        App.choose(1, from: "lower_quads", key: "lower_quads", name: "Quad pattern")
      ]
    )
  end

  defp install_foundations!(plan, actor) do
    App.add_track!(plan, "Daily habits",
      actor: actor,
      key: "daily_habits",
      event: "checklist_completed",
      description:
        "Daily baseline checklist. Keep this as the non-negotiables list rather than a place for one-off tasks.",
      schedule: App.every_day(),
      target: %{
        checklist_items: [
          %{key: "tidy_bedroom", label: "Tidy Bedroom"},
          %{key: "make_parents_breakfast", label: "Make parents breakfast"},
          %{key: "shower_brush_teeth", label: "Shower / Brush teeth"},
          %{key: "diet_followed", label: "16-8 diet followed"},
          %{key: "commit_code", label: "Commit code"},
          %{key: "avoid_alcohol", label: "Avoid Alcohol"},
          %{key: "avoid_junk_food", label: "Avoid Junk Food"}
        ],
        summary_template: "Completed daily habits"
      }
    )

    App.add_track!(plan, "Drink water",
      actor: actor,
      key: "drink_water",
      event: "quantity_logged",
      description:
        "Daily hydration target. Spread it through the day rather than trying to catch up at night.",
      schedule: App.every_day(),
      target: %{
        quantity: 3,
        unit: "litres",
        quantity_path: "payload.amount",
        summary_template: "Drank %{quantity} %{unit} water"
      }
    )
  end

  defp install_health!(plan, actor) do
    App.add_track!(plan, "Retatrutide",
      actor: actor,
      key: "retatrutide_dose",
      event: "dose_taken",
      description:
        "Weekly scheduled dose linked to the Retatrutide vial inventory so the remaining amount is tracked.",
      schedule: App.every_week(times: 1, on: [:monday]),
      target: %{
        quantity: 2,
        unit: "mg",
        quantity_path: "payload.amount",
        summary_template: "Took %{quantity} %{unit} Retatrutide",
        default_links: %{source_vial: "retatrutide"}
      }
    )
  end

  defp install_home!(plan, actor) do
    App.add_track!(plan, "Put bins out",
      actor: actor,
      key: "put_bins_out",
      event: "checklist_completed",
      description: "Weekly household reminder for bin day.",
      schedule: App.every_week(times: 1, on: [:wednesday]),
      target: %{
        checklist_items: [%{key: "put_bins_out", label: "Put bins out"}],
        summary_template: "Put bins out"
      }
    )
  end

  defp install_recovery!(plan, actor) do
    App.add_track!(plan, "Reading",
      actor: actor,
      key: "reading",
      event: "quantity_logged",
      description: "Daily reading target for decompression and mental wellbeing.",
      schedule: App.every_day(),
      target: %{
        quantity: 15,
        unit: "pages",
        quantity_path: "payload.amount",
        summary_template: "Read %{quantity} %{unit}"
      }
    )

    App.add_track!(plan, "Watch a film or TV series",
      actor: actor,
      key: "watch_film_or_tv",
      event: "quantity_logged",
      description:
        "Deliberate downtime. Pick a film or episode and let it count as planned recovery, not procrastination.",
      schedule: App.every_week(times: 3, on: [:wednesday, :friday, :sunday]),
      target: %{
        quantity: 90,
        unit: "min",
        quantity_path: "payload.amount",
        summary_template: "Watched %{quantity} %{unit}"
      }
    )

    App.add_track!(plan, "Listen to music or audiobook",
      actor: actor,
      key: "listen_music_or_audiobook",
      event: "quantity_logged",
      description: "Audio-based downtime. Listen to one album or a meaningful audiobook section.",
      schedule: App.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
      target: %{
        quantity: 1,
        unit: "album",
        quantity_path: "payload.amount",
        summary_template: "Listened to %{quantity} %{unit}"
      }
    )
  end
end
