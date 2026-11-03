defmodule LumenViaeWeb.Components.ChantMiniPlayer do
  @moduledoc """
  What the Chant Library is singing, at the foot of the site, as the iOS
  app's `ChantMiniPlayer` stands at the foot of the whole app: the chant's
  painting, its Latin name and where it stands (its English name and the
  time, or the set and "3 of 12", or "waiting for you" while a set waits
  between chants), its disc, and close. A tap on the names opens the
  chant's page.

  It is drawn once, empty and hidden, in the public root layout, outside
  every LiveView, beside the `<audio>` it plays through, so a chant goes
  on singing across live navigation. `assets/js/chant_session.js` holds
  the chant and `assets/js/chant_mini_player.js` fills this in and shows
  it. A page that carries its own transport or a prayer under way puts
  `data-hides-chant-player` on its outermost element, and the player
  stands aside there (the chant sings on), as the app's
  `showsChantPlayer`: a chant's own page, a Rosary prayed, an order of
  prayer prayed along, a Spiritual Reading chapter, a Consecration day
  (other than today's under a plan, the tab's root in the app) and the
  Act.
  """
  use Phoenix.Component

  alias LumenViae.Rosary.Library

  def mini_player(assigns) do
    assigns = assign(assigns, :origin, chant_origin())

    ~H"""
    <audio
      id="site-chant-audio"
      preload="none"
      data-role="site-chant-audio"
      data-origin={@origin}
    ></audio>
    <section
      id="chant-mini"
      class="chant-mini"
      aria-label="Chant player"
      data-role="chant-mini"
      hidden
    >
      <a
        href="/chant"
        class="chant-mini__open"
        data-role="mini-open"
        data-phx-link="redirect"
        data-phx-link-state="push"
      >
        <img class="chant-mini__thumb" data-role="mini-thumb" alt="" width="44" height="44" hidden />
        <span class="chant-mini__names">
          <span class="chant-mini__title" lang="la" data-role="mini-title"></span>
          <span class="chant-mini__subtitle" data-role="mini-subtitle"></span>
        </span>
        <span class="sr-only">, opens the chant</span>
      </a>
      <button
        type="button"
        class="chant-disc"
        data-act="toggle"
        data-role="mini-play"
        aria-label="Play"
        aria-pressed="false"
      >
        <span class="hero-play-solid size-3 chant-disc__play" aria-hidden="true" />
        <span class="hero-pause-solid size-3 chant-disc__pause" aria-hidden="true" />
      </button>
      <button
        type="button"
        class="chant-mini__close"
        data-act="close"
        data-role="mini-close"
        aria-label="Stop and close the player"
      >
        <span class="hero-x-mark size-4" aria-hidden="true" />
      </button>
      <span class="chant-mini__progress" aria-hidden="true">
        <span class="chant-mini__line" data-role="mini-progress"></span>
      </span>
    </section>
    """
  end

  @doc """
  The origin the chant recordings are served from (`scheme://host[:port]`),
  the one besides the site's own whose files the player takes back from
  this tab's storage.
  """
  def chant_origin do
    case URI.parse(Library.chant_asset_base()) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) ->
        port = if uri.port && uri.port != URI.default_port(scheme), do: ":#{uri.port}", else: ""
        "#{scheme}://#{host}#{port}"

      _other ->
        nil
    end
  end
end
