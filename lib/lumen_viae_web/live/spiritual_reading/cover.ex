defmodule LumenViaeWeb.Live.SpiritualReading.Cover do
  @moduledoc """
  A book of the shelf in its own cloth, as the app's `BookCover` binds it:
  True Devotion's binding (`TrueDevotion.Cover`, the `td-cover` classes)
  in the book's binding colour (`Shelf.cloth/1`, the `--color-cloth-*`
  tokens), with the gilt rules, the tooled frame, the title over a lozenge
  and the author at the foot. The marker ribbon over the top edge stands
  once a reading is under way; the `SpiritualReadingPlace` hook shows it,
  as the place is the browser's. Decorative: the page names the book.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Live.SpiritualReading.Shelf

  attr :book, :map, required: true
  attr :class, :string, default: nil

  def cover(assigns) do
    ~H"""
    <div class={["td-cover sr-cover", Shelf.cloth(@book.id), @class]} aria-hidden="true">
      <span class="td-cover__ribbon" data-role="ribbon" data-book={@book.id} hidden></span>
      <span class="td-cover__frame"></span>
      <span class="td-cover__gilt"></span>
      <span class="td-cover__title">{@book.title}</span>
      <span class="td-cover__lozenge"></span>
      <span class="td-cover__author">{@book.author}</span>
      <span class="td-cover__gilt"></span>
    </div>
    """
  end
end
