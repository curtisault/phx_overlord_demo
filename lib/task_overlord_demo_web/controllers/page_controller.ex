defmodule TaskOverlordDemoWeb.PageController do
  use TaskOverlordDemoWeb, :controller

  def tasks(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :tasks, layout: false)
  end

  def landing(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :landing, layout: false)
  end
end
