defmodule ImproveWeb.Router do
  use ImproveWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ImproveWeb do
    pipe_through :api
  end
end
