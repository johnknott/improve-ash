defmodule Improve.Repo.Migrations.AddFkIndexes do
  use Ecto.Migration

  def change do
    # plans
    create index(:plans, [:user_id])

    # event_instances — hot paths for projection and journal reads
    create index(:event_instances, [:plan_id, :effective_at])
    create index(:event_instances, [:event_type_id])
    create index(:event_instances, [:session_occurrence_id])
    create index(:event_instances, [:track_id])

    # item_effects — computing item state per event
    create index(:item_effects, [:event_instance_id])
    create index(:item_effects, [:plan_id, :item_id])

    # event_item_links — joining events to items
    create index(:event_item_links, [:event_instance_id])
    create index(:event_item_links, [:plan_id, :item_id])

    # slot_results — loading results for a session occurrence
    create index(:slot_results, [:session_occurrence_id])
    create index(:slot_results, [:plan_id])

    # session_occurrences — loading occurrences for a template/plan
    create index(:session_occurrences, [:plan_id, :session_template_id])

    # schedules
    create index(:schedules, [:plan_id])

    # pool_memberships — item lookups across pools
    create index(:pool_memberships, [:plan_id])
    create index(:pool_memberships, [:item_id])

    # items — item_type lookups
    create index(:items, [:item_type_id])

    # session_slots — pool lookups
    create index(:session_slots, [:pool_id])

    # tracks — event_type lookups
    create index(:tracks, [:event_type_id])
  end
end
