defmodule LumenViaeWeb.API.OfficeController do
  use LumenViaeWeb, :controller

  alias LumenViae.Office

  action_fallback LumenViaeWeb.API.FallbackController

  # An office, once assembled for a date, never changes, so every success
  # here may be cached by anyone for a day. Contrast the audio endpoints,
  # whose presigned URLs make their responses private and uncacheable.
  @cache_control "public, max-age=86400"

  def versions(conn, _params) do
    render(conn, :versions, vocabulary: Office.vocabulary())
  end

  def calendar(conn, %{"year" => year, "month" => month} = params) do
    with {:ok, calendar} <- Office.fetch_calendar(year, month, params) do
      conn
      |> put_resp_header("cache-control", @cache_control)
      |> render(:calendar, calendar: calendar)
    end
  end

  def day(conn, %{"date" => date} = params) do
    with {:ok, day} <- Office.fetch_day(date, params) do
      conn
      |> put_resp_header("cache-control", @cache_control)
      |> render(:day, day: day)
    end
  end

  def hour(conn, %{"date" => date, "hour" => hour} = params) do
    with {:ok, office_hour} <- Office.fetch_hour(date, hour, params) do
      conn
      |> put_resp_header("cache-control", @cache_control)
      |> render(:hour, hour: office_hour)
    end
  end
end
