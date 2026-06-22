defmodule Improve.Planning.ProjectTodayTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Plans
  alias Improve.Sessions

  describe "project_today/2" do
    test "projects today's gym work without mutating the database" do
      user =
        Accounts.create_user!(%{
          email: "project-gym@example.com",
          full_name: "Project Gym"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.plan_id == plan.id
      assert projection.date == ~D[2026-06-22]
      assert projection.diagnostics == []
      assert [_explanation] = projection.explanations

      assert [
               %{
                 session_template_name: "Upper-biased gym visit",
                 planned_for: ~D[2026-06-22],
                 recommendations: recommendations
               }
             ] = projection.projected_session_occurrences

      assert [
               %{
                 kind: :session,
                 status: :planned,
                 owner_type: :session_template,
                 title: "Upper-biased gym visit",
                 planned_for: ~D[2026-06-22],
                 payload: %{
                   session_occurrence: %{
                     session_template_name: "Upper-biased gym visit",
                     recommendations: ^recommendations
                   }
                 }
               }
             ] = projection.projected_work

      recommendation_counts =
        Map.new(recommendations, fn recommendation ->
          {recommendation.slot_key, Enum.map(recommendation.recommended_items, & &1.item_name)}
        end)

      assert %{
               "push" => push_items,
               "pull" => pull_items,
               "cardio" => cardio_items
             } = recommendation_counts

      assert length(push_items) == 2
      assert length(pull_items) == 2
      assert length(cardio_items) == 1
      assert Enum.all?(push_items ++ pull_items ++ cardio_items, &is_binary/1)

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "returns no projections outside the plan date range" do
      user =
        Accounts.create_user!(%{
          email: "project-outside@example.com",
          full_name: "Project Outside"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-09-01])

      assert projection.projected_session_occurrences == []
      assert projection.projected_work == []
      assert projection.diagnostics == []
      assert projection.explanations == ["No projected work is scheduled for this date."]
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end
  end
end
