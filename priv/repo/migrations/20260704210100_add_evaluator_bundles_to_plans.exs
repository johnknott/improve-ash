defmodule Improve.Repo.Migrations.AddEvaluatorBundlesToPlans do
  use Ecto.Migration

  def change do
    alter table(:plans) do
      add :evaluator_bundles, {:array, :string}, default: []
    end
  end
end
