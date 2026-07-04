defmodule Improve.Repo.Migrations.AddUniquenessIdentities do
  use Ecto.Migration

  def change do
    create unique_index(:session_occurrences, [:plan_id, :session_template_id, :planned_for],
             name: "session_occurrences_unique_occurrence_per_template_day_index"
           )

    create unique_index(:schedules, [:plan_id, :owner_type, :owner_id, :starts_on],
             name: "schedules_unique_schedule_per_owner_start_index"
           )
  end
end
