defmodule ImproveWeb.ErrorJSONTest do
  use ImproveWeb.ConnCase, async: true

  test "renders 404 in the shared error envelope" do
    assert ImproveWeb.ErrorJSON.render("404.json", %{}) ==
             %{error: %{code: "not_found", message: "Not Found", details: []}}
  end

  test "renders 500 in the shared error envelope" do
    assert ImproveWeb.ErrorJSON.render("500.json", %{}) ==
             %{error: %{code: "internal_error", message: "Internal Server Error", details: []}}
  end
end
