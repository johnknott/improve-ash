alias Improve.Accounts
alias Improve.Fixtures.GymPlan
alias Improve.Fixtures.VialPlan
alias Improve.Plans

seed_user =
  case Accounts.get_user_by_email("demo@improve.local") do
    {:ok, user} ->
      user

    {:error, %Ash.Error.Invalid{}} ->
      Accounts.create_user!(%{
        email: "demo@improve.local",
        full_name: "Improve Demo"
      })
  end

existing_source_keys =
  Plans.list_plans!(actor: seed_user)
  |> MapSet.new(& &1.source_key)

unless MapSet.member?(existing_source_keys, "gym") do
  GymPlan.install!(seed_user, starts_on: Date.utc_today())
end

unless MapSet.member?(existing_source_keys, "vial_inventory") do
  VialPlan.install!(seed_user, starts_on: Date.utc_today())
end

IO.puts("Seeded demo user demo@improve.local with gym and vial plans.")
