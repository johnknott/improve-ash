defmodule Improve.Repo.Migrations.CreateProposals do
  use Ecto.Migration

  def change do
    create table(:proposals, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :plan_id, references(:plans, type: :uuid, on_delete: :delete_all), null: false

      add :status, :text, null: false, default: "proposed"
      add :kind, :text, null: false
      add :source_evaluator, :text
      add :proposed_edit, :map, null: false
      add :evidence, :map, default: %{}
      add :affected_fields, {:array, :text}, default: []
      add :text, :text, null: false
      add :divergence_key, :text
      add :dismiss_reason, :text

      add :decided_at, :utc_datetime_usec
      add :applied_at, :utc_datetime_usec
      add :refreshed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:proposals, [:plan_id])
    create index(:proposals, [:plan_id, :status])

    create unique_index(:proposals, [:plan_id, :divergence_key],
             where: "status = 'proposed' AND divergence_key IS NOT NULL",
             name: :proposals_unique_divergence_per_plan
           )
  end
end
