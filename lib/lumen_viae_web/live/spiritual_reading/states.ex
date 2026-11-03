defmodule LumenViaeWeb.Live.SpiritualReading.States do
  @moduledoc """
  What a book's page or a chapter says while its text is on the way, or
  when it could not be had, in the app's words (`LibraryBookView`'s
  `loading` and `unavailable`, `LibraryError`): Gutenberg out of reach is
  worth a Try again (the `retry` event); an edition that no longer cuts
  into chapters is not, as trying again only fetches it to fail the same
  way. The app tells the reader to check their connection; here it is the
  server that fetches, so the site says only to try again in a moment.
  """
  use LumenViaeWeb, :html

  def loading(assigns) do
    ~H"""
    <div class="sr-state" role="status" aria-live="polite" data-role="loading">
      <span class="sr-state__spinner" aria-hidden="true"></span>
      <p>Fetching the text from Project Gutenberg.</p>
    </div>
    """
  end

  attr :failure, :atom, required: true

  def unavailable(assigns) do
    ~H"""
    <div class="sr-state" role="alert" data-role="unavailable">
      <%= if @failure == :unreadable do %>
        <p class="sr-state__title">This edition can't be opened</p>
        <p>
          Project Gutenberg's edition of this book has changed shape, so it can't be cut into
          chapters. It will return in a coming update.
        </p>
      <% else %>
        <p class="sr-state__title">Couldn't reach the library</p>
        <p>The text comes from Project Gutenberg, which could not be reached just now.</p>
        <button type="button" phx-click="retry" class="btn-text" data-role="retry">
          <span class="hero-arrow-path size-3.5" aria-hidden="true" /> Try again
        </button>
      <% end %>
    </div>
    """
  end
end
