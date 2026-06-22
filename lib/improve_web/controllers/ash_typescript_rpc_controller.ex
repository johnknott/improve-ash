defmodule ImproveWeb.AshTypescriptRpcController do
  use ImproveWeb, :controller

  def run(conn, params) do
    json(conn, AshTypescript.Rpc.run_action(:improve, conn, params))
  end

  def validate(conn, params) do
    json(conn, AshTypescript.Rpc.validate_action(:improve, conn, params))
  end
end
