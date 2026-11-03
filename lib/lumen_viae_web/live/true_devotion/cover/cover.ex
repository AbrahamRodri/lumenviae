defmodule LumenViaeWeb.Live.TrueDevotion.Cover do
  @moduledoc """
  True Devotion's binding as the app draws it (`BookCover` over its
  `BookHalo`; Android's `BookParts.kt`): Marian-blue cloth with the hinge's
  shadow down the spine, a tooled gilt frame, double gilt rules at head and
  tail, the title in gold capitals over a lozenge and the author at the
  foot, the halo of the cloth's blue glowing behind it. The marker ribbon
  over the top edge stands once a reading is under way; the
  `TrueDevotionPlace` hook shows it, as the place is the browser's.
  Decorative: the page says the title and author in its heading.
  """
  use LumenViaeWeb, :html

  attr :title, :string, required: true
  attr :author, :string, required: true

  def cover(assigns) do
    ~H"""
    <div class="td-cover-stage" aria-hidden="true">
      <span class="td-halo"></span>
      <div class="td-cover">
        <span class="td-cover__ribbon" data-role="ribbon" hidden></span>
        <span class="td-cover__frame"></span>
        <span class="td-cover__gilt"></span>
        <span class="td-cover__title">{@title}</span>
        <span class="td-cover__lozenge"></span>
        <span class="td-cover__author">{@author}</span>
        <span class="td-cover__gilt"></span>
      </div>
    </div>
    """
  end
end
