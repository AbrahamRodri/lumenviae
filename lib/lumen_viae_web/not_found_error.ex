defmodule LumenViaeWeb.NotFoundError do
  @moduledoc """
  Raised when a public page is requested with an unknown resource,
  such as an invalid mystery category. Rendered as a 404 response.
  """
  defexception message: "not found", plug_status: 404
end
