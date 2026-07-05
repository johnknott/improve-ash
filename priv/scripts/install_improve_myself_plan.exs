# Installs the "Improve myself!" plan — John's real plan exported from the
# previous Improve app — for a local dev user. The plan is defined in the
# fixture module Improve.Fixtures.ImproveMyselfPlan, which db:seed also uses,
# so this script and the seed stay in lockstep. Source export:
# priv/drafts/improve-myself.plan-draft-v1.json
#
# Usage:
#   mix run priv/scripts/install_improve_myself_plan.exs [email]
#   (defaults to demo@improve.local; reruns are skipped once installed)

alias Improve.Accounts
alias Improve.Fixtures.ImproveMyselfPlan
alias Improve.Plans

email = List.first(System.argv()) || "demo@improve.local"

user =
  case Accounts.get_user_by_email(email, authorize?: false) do
    {:ok, user} -> user
    {:error, _} -> Accounts.create_user!(%{email: email, full_name: "Improve Demo"})
  end

existing =
  Plans.list_plans!(actor: user)
  |> Enum.find(&(&1.source_key == ImproveMyselfPlan.source_key()))

if existing do
  IO.puts("Plan already installed for #{email} (#{existing.id}). Nothing to do.")
else
  plan = ImproveMyselfPlan.install!(user)
  summary = Plans.summarize_plan!(plan, actor: user)

  IO.puts(
    "Installed \"Improve myself!\" for #{email}: " <>
      "#{summary.tracks} tracks, #{summary.session_templates} sessions, " <>
      "#{summary.items} items, #{summary.event_types} event types."
  )
end
