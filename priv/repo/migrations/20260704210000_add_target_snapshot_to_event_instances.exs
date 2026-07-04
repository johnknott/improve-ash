defmodule Improve.Repo.Migrations.AddTargetSnapshotToEventInstances do
  use Ecto.Migration

  def change do
    alter table(:event_instances) do
      add :target_snapshot, :map
    end
  end
end
