defmodule LumenViaeWeb.NotFoundError do
  @moduledoc """
  Raised when a public page is requested with an unknown resource,
  such as an invalid mystery category. Rendered as a 404 response.

  `removed` names what was there once and was taken off (`:novena`), so
  the 404 page can say so and point to what remains instead of
  suggesting a typing error.
  """
  defexception message: "not found", plug_status: 404, removed: nil
end
