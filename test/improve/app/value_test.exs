defmodule Improve.App.ValueTest do
  use ExUnit.Case, async: true

  alias Improve.App.Value

  describe "default_datetime/2" do
    test "defaults date-only logging to 20:00 in the user's time zone, stored as UTC" do
      # London is UTC+1 on this date, so 20:00 local is 19:00 UTC.
      assert Value.default_datetime(~D[2026-06-22], "Europe/London") ==
               ~U[2026-06-22 19:00:00Z]
    end

    test "falls back to 20:00 UTC without a time zone" do
      assert Value.default_datetime(~D[2026-06-22]) == ~U[2026-06-22 20:00:00Z]
      assert Value.default_datetime(~D[2026-06-22], nil) == ~U[2026-06-22 20:00:00Z]
    end
  end
end
