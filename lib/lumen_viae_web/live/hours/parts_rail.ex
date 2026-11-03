defmodule LumenViaeWeb.Live.Hours.PartsRail do
  @moduledoc """
  The parts of a text to jump between, as an hour of the Office and a day
  of the Missal both offer them: a rail beside the text from 1024px, lit
  as the reader passes each part (the `OfficeRail` hook, on the element
  holding both the rail and the text), and a folded jump list above the
  text on a phone. Each part is a map with the `id` of its section, which
  carries `data-rail-section` with that id, and the `rail_name` to show.
  """
  use LumenViaeWeb, :html

  attr :parts, :list, required: true, doc: "each `%{id:, rail_name:}`"
  attr :label, :string, required: true, doc: "what the parts are of, for the list's name"

  @doc "The folded list above the text on a phone."
  def jump_list(assigns) do
    ~H"""
    <details :if={@parts != []} class="hours-jump" data-role="jump-list">
      <summary class="hours-jump__summary">{@label}</summary>
      <ol class="hours-jump__list">
        <li :for={part <- @parts}>
          <a href={"##{part.id}"} class="hours-jump__link">{part.rail_name}</a>
        </li>
      </ol>
    </details>
    """
  end

  attr :parts, :list, required: true, doc: "each `%{id:, rail_name:}`"
  attr :label, :string, required: true, doc: "the rail's name for assistive technology"
  attr :kicker, :string, required: true, doc: "the small heading over the rail"

  @doc "The rail beside the text from 1024px."
  def rail(assigns) do
    ~H"""
    <nav :if={@parts != []} class="hours-rail" aria-label={@label} data-role="rail">
      <p class="hours-rail__kicker">{@kicker}</p>
      <ol>
        <li :for={part <- @parts}>
          <a href={"##{part.id}"} class="hours-rail__link" data-rail-link={part.id}>
            {part.rail_name}
          </a>
        </li>
      </ol>
    </nav>
    """
  end
end
