defmodule LumenViaeWeb.Live.Home.App.Clip do
  @moduledoc """
  One phone on the app page: a short silent loop of the app in its
  Midnight theme, drawn in a CSS phone (`.app-phone` in `app.css`).

  A clip `name` (`c1-player`) is three files in
  `priv/static/images/app/clips/`: `<name>.mp4` (H.264, 600 px wide, no
  audio track, under 1 MB), and its first frame as `<name>.webp` and
  `<name>.jpg`, the poster. The video loads nothing until the page is
  shown, plays only while it is on screen (the `AppClip` hook), never
  when the visitor asks for reduced motion, and has a round Pause/Play
  button: the mark only, its name in `aria-label` (design, 17 Nov 2026:
  a word in a pill overhung the phone in Spanish).

  The files are served for a week under their names (`LumenViaeWeb.Endpoint`),
  so a clip recorded again takes a new name. See docs/PUBLIC_SITE.md.
  """
  use Phoenix.Component

  # The clip's width and height on the page's own scale: 600x1304 files.
  @width 600
  @height 1304

  attr :name, :string, required: true
  attr :alt, :string, required: true, doc: "what the clip shows"
  attr :pause, :string, required: true, doc: "the Pause button's name, for screen readers"
  attr :play, :string, required: true, doc: "the Play button's name, for screen readers"
  attr :class, :any, default: nil

  def clip(assigns) do
    assigns = assign(assigns, width: @width, height: @height)

    ~H"""
    <figure
      id={"clip-#{@name}"}
      class={["app-phone", @class]}
      phx-hook="AppClip"
      phx-update="ignore"
      data-pause={@pause}
      data-play={@play}
    >
      <video
        class="app-phone__screen"
        width={@width}
        height={@height}
        muted
        loop
        playsinline
        preload="none"
        poster={"/images/app/clips/#{@name}.jpg"}
        aria-label={@alt}
      >
        <source src={"/images/app/clips/#{@name}.mp4"} type="video/mp4" />
      </video>
      <button
        type="button"
        class="app-phone__toggle"
        data-role="clip-toggle"
        aria-label={@pause}
        hidden
      >
        <svg class="app-phone__mark-play" viewBox="0 0 16 16" aria-hidden="true">
          <path d="M5 3.2v9.6l8-4.8z" fill="currentColor" />
        </svg>
        <svg class="app-phone__mark-pause" viewBox="0 0 16 16" aria-hidden="true">
          <rect x="4" y="3.5" width="2.6" height="9" rx="0.6" fill="currentColor" />
          <rect x="9.4" y="3.5" width="2.6" height="9" rx="0.6" fill="currentColor" />
        </svg>
      </button>
    </figure>
    """
  end
end
