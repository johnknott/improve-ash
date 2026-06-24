alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("translated_old_plan_rough", reset?: true)
  |> Story.user!("John", email: "story+translated-old-plan@example.test")

actor = story.user

plan =
  App.create_plan!("Improve myself!",
    actor: actor,
    intention: "Improve my fitness and mental health",
    from: ~D[2026-06-16],
    until: ~D[2026-08-06]
  )

# Event types

App.add_event_type!(plan, "Metric logged",
  actor: actor,
  key: "metric_logged",
  payload: %{
    required: ["value", "unit"],
    properties: %{
      value: %{type: "number"},
      unit: %{type: "string"},
      note: %{type: "string"}
    }
  }
)

App.add_event_type!(plan, "Quantity logged",
  actor: actor,
  key: "quantity_logged",
  payload: %{
    required: ["amount", "unit"],
    properties: %{
      amount: %{type: "number"},
      unit: %{type: "string"},
      note: %{type: "string"}
    }
  }
)

App.add_event_type!(plan, "Checklist completed",
  actor: actor,
  key: "checklist_completed",
  payload: %{
    required: ["completed_items"],
    properties: %{
      completed_items: %{type: "array"},
      note: %{type: "string"}
    }
  }
)

App.add_event_type!(plan, "Exercise performed",
  actor: actor,
  key: "exercise_performed",
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

# Stateful vial/resource translated into an item plus an effectful event.

App.add_item_type!(plan, "Peptide vial",
  actor: actor,
  key: "peptide_vial",
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
    App.subtract_quantity(
      from: "source_vial",
      quantity: "payload.amount",
      unit: "payload.unit"
    )
  ]
)

# Body metrics

App.add_track!(plan, "Weigh myself",
  actor: actor,
  key: "weigh_myself",
  event: "metric_logged",
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
  schedule: App.every_week(times: 1, on: [:tuesday]),
  target: %{
    unit: "cm",
    quantity_path: "payload.value",
    summary_template: "Logged waist: %{quantity} %{unit}"
  }
)

# Daily movement and cardio

App.add_track!(plan, "Steps",
  actor: actor,
  key: "steps",
  event: "quantity_logged",
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

# Strength items and pools

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

# Old Tue/Thu gym tracks translated into one upper-body session.

App.add_session!(plan, "Upper body gym visit",
  actor: actor,
  key: "upper_body_gym",
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

# Old Saturday lower-body tracks translated into one lower-body session.

App.add_session!(plan, "Lower body gym visit",
  actor: actor,
  key: "lower_body_gym",
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

# Daily foundations

App.add_track!(plan, "Daily habits",
  actor: actor,
  key: "daily_habits",
  event: "checklist_completed",
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
  schedule: App.every_day(),
  target: %{
    quantity: 3,
    unit: "litres",
    quantity_path: "payload.amount",
    summary_template: "Drank %{quantity} %{unit} water"
  }
)

# Health

App.add_track!(plan, "Retatrutide",
  actor: actor,
  key: "retatrutide_dose",
  event: "dose_taken",
  schedule: App.every_week(times: 1, on: [:monday]),
  target: %{
    quantity: 2,
    unit: "mg",
    quantity_path: "payload.amount",
    summary_template: "Took %{quantity} %{unit} Retatrutide",
    default_links: %{source_vial: "retatrutide"}
  }
)

# Home

App.add_track!(plan, "Put bins out",
  actor: actor,
  key: "put_bins_out",
  event: "checklist_completed",
  schedule: App.every_week(times: 1, on: [:wednesday]),
  target: %{
    checklist_items: [%{key: "put_bins_out", label: "Put bins out"}],
    summary_template: "Put bins out"
  }
)

# Recovery and mind

App.add_track!(plan, "Reading",
  actor: actor,
  key: "reading",
  event: "quantity_logged",
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
  schedule: App.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
  target: %{
    quantity: 1,
    unit: "album",
    quantity_path: "payload.amount",
    summary_template: "Listened to %{quantity} %{unit}"
  }
)

# Inspect the translated plan.

Story.show_plan_summary!(story, plan)
Story.show_item_state!(story, plan, "retatrutide")

monday = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, monday)

App.log_event!(plan,
  actor: actor,
  event: "dose_taken",
  track: "retatrutide_dose",
  on: ~D[2026-06-22],
  summary: "Took 2 mg Retatrutide",
  links: %{source_vial: "retatrutide"},
  payload: %{amount: 2, unit: "mg", site: "abdomen"}
)

Story.show_item_state!(story, plan, "retatrutide")
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])

tuesday = App.project_today!(plan, actor: actor, date: ~D[2026-06-23])
Story.show_projection!(story, tuesday)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])

saturday = App.project_today!(plan, actor: actor, date: ~D[2026-06-27])
Story.show_projection!(story, saturday)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-27])
