defmodule LumenViaeWeb.Components.MysteryCard do
  @moduledoc """
  Reusable component for displaying mystery cards with scripture
  """
  use Phoenix.Component

  @doc """
  Renders a mystery card with title, description, and scripture details
  """
  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :scripture_reference, :string, required: true
  slot :scripture_content, required: true

  def mystery_card(assigns) do
    ~H"""
    <div class="bg-white p-3 md:p-4 rounded-lg shadow-soft border-l-4 border-gold transition-all duration-300 hover:shadow-ornate hover:-translate-y-1">
      <h3 class="font-ovo text-navy text-base md:text-lg lg:text-xl mb-1 md:mb-2">
        {@number}. {@title}
      </h3>
      <p class="font-work-sans text-brown leading-relaxed text-xs md:text-sm mb-2">
        {@description}
      </p>
      <details class="mt-2 md:mt-3">
        <summary class="font-ovo text-gold-dark cursor-pointer hover:text-gold text-xs uppercase tracking-wide transition-colors">
          Read Scripture <span class="text-gold-light font-bold">({@scripture_reference})</span>
        </summary>
        <div class="mt-2 md:mt-3 p-2 md:p-3 bg-cream-dark rounded border-l-2 border-gold">
          <div class="font-garamond text-brown text-xs md:text-sm leading-relaxed">
            {render_slot(@scripture_content)}
          </div>
        </div>
      </details>
    </div>
    """
  end

  @doc """
  Renders a mystery section header
  """
  attr :title, :string, required: true
  attr :schedule, :string, required: true

  def mystery_section_header(assigns) do
    ~H"""
    <div class="text-center mb-6 md:mb-8">
      <h2 class="font-ovo text-navy text-xl md:text-2xl lg:text-3xl mb-2 md:mb-3">
        {@title}
      </h2>
      <p class="font-work-sans text-brown italic text-xs">
        {@schedule}
      </p>
    </div>
    """
  end
end
