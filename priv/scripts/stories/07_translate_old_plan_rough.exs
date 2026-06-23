alias Improve.Stories, as: Story

story =
  Story.begin!("translated_old_plan_rough", reset?: true)
  |> Story.user!("John", email: "story+translated-old-plan@example.test")

plan =
  Story.create_plan!(story, "Improve myself!",
    intention: "Improve my fitness and mental health",
    from: ~D[2026-06-16],
    until: ~D[2026-08-06]
  )

# Event types

Story.add_event_type!(story, plan, "Metric logged",
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

Story.add_event_type!(story, plan, "Quantity logged",
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

Story.add_event_type!(story, plan, "Checklist completed",
  key: "checklist_completed",
  payload: %{
    required: ["completed_items"],
    properties: %{
      completed_items: %{type: "array"},
      note: %{type: "string"}
    }
  }
)

Story.add_event_type!(story, plan, "Exercise performed",
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

Story.add_event_type!(story, plan, "Cardio performed",
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

Story.add_item_type!(story, plan, "Peptide vial",
  key: "peptide_vial",
  display_hints: %{kind: "inventory"}
)

Story.add_item!(story, plan, "Retatrutide",
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

Story.add_event_type!(story, plan, "Dose taken",
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
    Story.subtract_quantity(
      from: "source_vial",
      quantity: "payload.amount",
      unit: "payload.unit"
    )
  ]
)

# Body metrics

Story.add_direct_goal!(story, plan, "Weigh myself",
  key: "weigh_myself",
  event: "metric_logged",
  schedule: Story.every_day(),
  target: %{
    unit: "kg",
    quantity_path: "payload.value",
    summary_template: "Logged weight: %{quantity} %{unit}"
  }
)

Story.add_direct_goal!(story, plan, "Measure waist",
  key: "measure_waist",
  event: "metric_logged",
  schedule: Story.every_week(times: 1, on: [:tuesday]),
  target: %{
    unit: "cm",
    quantity_path: "payload.value",
    summary_template: "Logged waist: %{quantity} %{unit}"
  }
)

# Daily movement and cardio

Story.add_direct_goal!(story, plan, "Steps",
  key: "steps",
  event: "quantity_logged",
  schedule: Story.every_day(),
  target: %{
    quantity: 10_000,
    unit: "steps",
    quantity_path: "payload.amount",
    summary_template: "Logged %{quantity} %{unit}",
    progression: %{from: 1_000, to: 10_000, shape: "linear"}
  }
)

Story.add_item_type!(story, plan, "Cardio activity", key: "cardio_activity")

Story.add_item!(story, plan, "Cycling", key: "cycling", type: "cardio_activity")
Story.add_item!(story, plan, "Rowing", key: "rowing", type: "cardio_activity")
Story.add_item!(story, plan, "Elliptical", key: "elliptical", type: "cardio_activity")

Story.add_direct_goal!(story, plan, "Cycling",
  key: "cycling",
  event: "cardio_performed",
  schedule: Story.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
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

Story.add_item_type!(story, plan, "Exercise", key: "exercise")

Story.add_exercise!(story, plan, "Chest Press", key: "chest_press")
Story.add_exercise!(story, plan, "Lat Pulldown", key: "lat_pulldown")
Story.add_exercise!(story, plan, "Shoulder Press", key: "shoulder_press")

Story.add_exercise!(story, plan, "Leg Press", key: "leg_press")
Story.add_exercise!(story, plan, "Leg Curl", key: "leg_curl")
Story.add_exercise!(story, plan, "Leg Extension", key: "leg_extension")

Story.add_pool!(story, plan, "Upper cardio warm-up",
  key: "upper_cardio",
  items: ["rowing", "elliptical"]
)

Story.add_pool!(story, plan, "Upper body push", key: "upper_push", items: ["chest_press"])
Story.add_pool!(story, plan, "Upper body pull", key: "upper_pull", items: ["lat_pulldown"])
Story.add_pool!(story, plan, "Upper body shoulders", key: "upper_shoulders", items: ["shoulder_press"])

Story.add_pool!(story, plan, "Lower cardio warm-up",
  key: "lower_cardio",
  items: ["rowing", "elliptical"]
)

Story.add_pool!(story, plan, "Lower body press", key: "lower_press", items: ["leg_press"])
Story.add_pool!(story, plan, "Lower body hamstrings", key: "lower_hamstrings", items: ["leg_curl"])
Story.add_pool!(story, plan, "Lower body quads", key: "lower_quads", items: ["leg_extension"])

# Old Tue/Thu gym tracks translated into one upper-body session.

Story.add_session!(story, plan, "Upper body gym visit",
  key: "upper_body_gym",
  schedule: Story.every_week(times: 2, on: [:tuesday, :thursday]),
  slots: [
    Story.choose(2, from: "upper_cardio", key: "upper_cardio", name: "Warm-up cardio"),
    Story.choose(1, from: "upper_push", key: "upper_push", name: "Push pattern"),
    Story.choose(1, from: "upper_pull", key: "upper_pull", name: "Pull pattern"),
    Story.choose(1, from: "upper_shoulders", key: "upper_shoulders", name: "Shoulder pattern")
  ]
)

# Awkwardness exposed: these session slots probably want default event/payload
# hints, but the current story API only records the slot choices.

# Old Saturday lower-body tracks translated into one lower-body session.

Story.add_session!(story, plan, "Lower body gym visit",
  key: "lower_body_gym",
  schedule: Story.every_week(times: 1, on: [:saturday]),
  slots: [
    Story.choose(2, from: "lower_cardio", key: "lower_cardio", name: "Warm-up cardio"),
    Story.choose(1, from: "lower_press", key: "lower_press", name: "Press pattern"),
    Story.choose(1, from: "lower_hamstrings", key: "lower_hamstrings", name: "Hamstring pattern"),
    Story.choose(1, from: "lower_quads", key: "lower_quads", name: "Quad pattern")
  ]
)

# Daily foundations

Story.add_direct_goal!(story, plan, "Daily habits",
  key: "daily_habits",
  event: "checklist_completed",
  schedule: Story.every_day(),
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

Story.add_direct_goal!(story, plan, "Drink water",
  key: "drink_water",
  event: "quantity_logged",
  schedule: Story.every_day(),
  target: %{
    quantity: 3,
    unit: "litres",
    quantity_path: "payload.amount",
    summary_template: "Drank %{quantity} %{unit} water"
  }
)

# Health

Story.add_direct_goal!(story, plan, "Retatrutide",
  key: "retatrutide_dose",
  event: "dose_taken",
  schedule: Story.every_week(times: 1, on: [:monday]),
  target: %{
    quantity: 2,
    unit: "mg",
    quantity_path: "payload.amount",
    summary_template: "Took %{quantity} %{unit} Retatrutide",
    default_links: %{source_vial: "retatrutide"}
  }
)

# Home

Story.add_direct_goal!(story, plan, "Put bins out",
  key: "put_bins_out",
  event: "checklist_completed",
  schedule: Story.every_week(times: 1, on: [:wednesday]),
  target: %{
    checklist_items: [%{key: "put_bins_out", label: "Put bins out"}],
    summary_template: "Put bins out"
  }
)

# Recovery and mind

Story.add_direct_goal!(story, plan, "Reading",
  key: "reading",
  event: "quantity_logged",
  schedule: Story.every_day(),
  target: %{
    quantity: 15,
    unit: "pages",
    quantity_path: "payload.amount",
    summary_template: "Read %{quantity} %{unit}"
  }
)

Story.add_direct_goal!(story, plan, "Watch a film or TV series",
  key: "watch_film_or_tv",
  event: "quantity_logged",
  schedule: Story.every_week(times: 3, on: [:wednesday, :friday, :sunday]),
  target: %{
    quantity: 90,
    unit: "min",
    quantity_path: "payload.amount",
    summary_template: "Watched %{quantity} %{unit}"
  }
)

Story.add_direct_goal!(story, plan, "Listen to music or audiobook",
  key: "listen_music_or_audiobook",
  event: "quantity_logged",
  schedule: Story.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
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

monday = Story.project_today!(story, plan, on: ~D[2026-06-22])
Story.show_projection!(story, monday)

Story.log_event!(story, plan,
  event: "dose_taken",
  goal: "retatrutide_dose",
  on: ~D[2026-06-22],
  summary: "Took 2 mg Retatrutide",
  links: %{source_vial: "retatrutide"},
  payload: %{amount: 2, unit: "mg", site: "abdomen"}
)

Story.show_item_state!(story, plan, "retatrutide")
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])

tuesday = Story.project_today!(story, plan, on: ~D[2026-06-23])
Story.show_projection!(story, tuesday)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])

saturday = Story.project_today!(story, plan, on: ~D[2026-06-27])
Story.show_projection!(story, saturday)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-27])
