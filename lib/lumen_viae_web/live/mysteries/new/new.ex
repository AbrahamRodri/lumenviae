defmodule LumenViaeWeb.Live.Mysteries.New do
  use LumenViaeWeb, :live_view
  alias LumenViae.Rosary

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Mystery")
     |> assign_mystery_form()}
  end

  def handle_event("create_mystery", params, socket) do
    case Rosary.create_mystery(params) do
      {:ok, mystery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Mystery created successfully")
         |> push_navigate(to: "/admin/mysteries/#{mystery.id}/edit")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create mystery: #{format_errors(changeset)}")
         |> assign(:mystery_form, to_form(changeset))}
    end
  end

  defp assign_mystery_form(socket) do
    assign(
      socket,
      :mystery_form,
      to_form(%{
        "name" => "",
        "category" => "",
        "order" => "",
        "days_prayed" => "",
        "description" => "",
        "scripture_reference" => ""
      })
    )
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
