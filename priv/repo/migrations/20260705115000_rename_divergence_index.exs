defmodule Improve.Repo.Migrations.RenameDivergenceIndex do
  @moduledoc """
  The hand-written proposals divergence index predates working migration
  snapshots (the generator was crashing on a missing identity_wheres_to_sql
  entry) and lacks the `_index` suffix Ash uses to translate unique-violation
  errors back to the identity. Rename only; definition already matches.
  """

  use Ecto.Migration

  def up do
    execute "ALTER INDEX proposals_unique_divergence_per_plan RENAME TO proposals_unique_divergence_per_plan_index"
  end

  def down do
    execute "ALTER INDEX proposals_unique_divergence_per_plan_index RENAME TO proposals_unique_divergence_per_plan"
  end
end
