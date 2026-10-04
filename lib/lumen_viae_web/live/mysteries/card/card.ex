defmodule LumenViaeWeb.Live.Mysteries.Card do
  @moduledoc """
  The painting on a category's card, for a category whose card is not one
  of its mysteries' paintings: the Seven Sorrows' Pieta today. The four
  Rosaries' cards show their first mystery's painting, set on that
  mystery's own page, so this page refuses them.

  Nothing is written by opening the page: the card's row is created the
  first time a painting or its details are saved.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Admin.ArtworkEditing

  @artwork_events ArtworkEditing.events()

  def mount(%{"slug" => slug}, _session, socket) do
    if slug in Categories.slugs() and Categories.card_mystery_key(slug) == nil do
      card = Rosary.get_category_card!(slug, actor: socket.assigns.current_admin)

      {:ok,
       socket
       |> assign(:page_title, "#{Categories.label(slug)} card")
       |> assign(:slug, slug)
       |> ArtworkEditing.setup(card, artwork_config(slug))}
    else
      {:ok,
       socket
       |> put_flash(
         :error,
         "That category's card shows its first mystery's painting: upload it on that mystery's page."
       )
       |> push_navigate(to: "/admin/mysteries")}
    end
  end

  def handle_event(event, params, socket) when event in @artwork_events do
    ArtworkEditing.handle(event, params, socket)
  end

  defp artwork_config(slug) do
    %{
      scope: :category_card,
      noun: "Card painting",
      ensure: fn
        nil, opts -> Rosary.ensure_category_card(slug, opts)
        card, _opts -> {:ok, card}
      end,
      record_artwork: &Rosary.update_category_card_artwork/3,
      update_metadata: &Rosary.update_category_card_artwork_metadata/3,
      metadata_form: fn card, opts ->
        Rosary.form_to_update_category_card_artwork_metadata(card, [as: "artwork"] ++ opts)
      end,
      saved: fn socket, _card -> socket end
    }
  end
end
