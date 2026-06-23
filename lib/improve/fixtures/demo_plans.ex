defmodule Improve.Fixtures.DemoPlans do
  @moduledoc """
  Demo plan registry for UI smoke data.

  Runtime app APIs call this module so scenario-specific fixture names stay out
  of the product workflow code.
  """

  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan

  def fetch("gym"), do: {:ok, "gym", &GymPlan.install!/2}
  def fetch("vial_inventory"), do: {:ok, "vial_inventory", &VialPlan.install!/2}
  def fetch("vial"), do: fetch("vial_inventory")
  def fetch(_kind), do: {:error, :unknown_demo_plan}
end
