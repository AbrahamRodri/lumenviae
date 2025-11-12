defmodule LumenViaeWeb.Components.Scripture do
  @moduledoc """
  Reusable scripture display component for the Rosary mysteries.
  """
  use Phoenix.Component

  @doc """
  Renders a scripture passage with collapsible details.

  ## Examples

      <.scripture reference="Luke 1:26–38 - Douay-Rheims">
        <span class="text-gold font-semibold">1:26</span> And in the sixth month...
      </.scripture>

  Or with the scripture key:

      <.scripture_by_key key={:annunciation} />
  """
  attr :reference, :string, required: true, doc: "The scripture reference (e.g., 'Luke 1:26–38')"
  slot :inner_block, required: true

  def scripture(assigns) do
    ~H"""
    <details class="mt-4">
      <summary class="font-ovo text-gold-dark cursor-pointer hover:text-gold transition-colors text-sm uppercase tracking-wide">
        Read Scripture <span class="text-gold-light">({@reference})</span>
      </summary>
      <div class="mt-4 p-4 bg-cream-dark rounded border-l-2 border-gold">
        <p class="font-garamond text-brown text-base leading-loose">
          <%= render_slot(@inner_block) %>
        </p>
      </div>
    </details>
    """
  end

  @doc """
  Renders a scripture passage by key from LumenViae.Scripture module.
  """
  attr :key, :atom, required: true, doc: "The scripture key from LumenViae.Scripture"

  def scripture_by_key(assigns) do
    scripture = LumenViae.Scripture.get(assigns.key)

    assigns =
      if scripture do
        assigns
        |> assign(:reference, scripture.reference)
        |> assign(:verses, scripture.verses)
      else
        assigns
        |> assign(:reference, "Scripture not found")
        |> assign(:verses, [])
      end

    ~H"""
    <details class="mt-4">
      <summary class="font-ovo text-gold-dark cursor-pointer hover:text-gold transition-colors text-sm uppercase tracking-wide">
        Read Scripture <span class="text-gold-light">({@reference})</span>
      </summary>
      <div class="mt-4 p-4 bg-cream-dark rounded border-l-2 border-gold">
        <p class="font-garamond text-brown text-base leading-loose">
          <%= for {verse_num, text} <- @verses do %>
            <span class="text-gold font-semibold"><%= verse_num %></span>
            <%= text %>
          <% end %>
        </p>
      </div>
    </details>
    """
  end
end
