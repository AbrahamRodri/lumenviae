defmodule LumenViaeWeb.Live.Home.App.Clip do
  @moduledoc """
  One phone on the app page: a short silent loop of the app in its
  Midnight theme, drawn in a CSS phone (`.app-phone` in `app.css`).

  A clip `name` (`c1-player`) is three files in
  `priv/static/images/app/clips/`: `<name>.mp4` (H.264, 600 px wide, no
  audio track, under 1 MB), and its first frame as `<name>.webp` and
  `<name>.jpg`, the poster. The video loads nothing until the page is
  shown, plays only while it is on screen (the `AppClip` hook), never
  when the visitor asks for reduced motion, and has a Pause button.

  Until a clip's files are there, the phone shows the still named in
  `@stand_in` instead, so the page can be built before the clips are
  recorded. Nothing ships with a stand-in: see docs/PUBLIC_SITE.md.
  """
  use Phoenix.Component

  @stand_in %{"c1-player" => "player", "c6-hours" => "hours", "c7-prayers" => "prayers"}

  # The clip's width and height on the page's own scale: 600x1304 files.
  @width 600
  @height 1304

  attr :name, :string, required: true
  attr :alt, :string, required: true, doc: "what the clip shows"
  attr :pause, :string, required: true, doc: "the Pause button's word"
  attr :play, :string, required: true, doc: "the Play button's word"
  attr :class, :any, default: nil
  attr :loading, :string, default: "lazy", values: ~w(lazy eager)

  def clip(assigns) do
    assigns =
      assign(assigns,
        recorded?: recorded?(assigns.name),
        stand_in: Map.get(@stand_in, assigns.name),
        width: @width,
        height: @height
      )

    ~H"""
    <figure
      :if={@recorded?}
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
      <button type="button" class="app-phone__toggle" data-role="clip-toggle" hidden>
        {@pause}
      </button>
    </figure>
    <figure :if={!@recorded?} class={["app-phone", @class]}>
      <picture>
        <source
          type="image/webp"
          srcset={"/images/app/#{@stand_in}-390.webp 390w, /images/app/#{@stand_in}-780.webp 780w"}
          sizes="(min-width: 768px) 300px, 260px"
        />
        <img
          src={"/images/app/#{@stand_in}.jpg"}
          width="390"
          height="848"
          alt={@alt}
          loading={@loading}
          decoding="async"
          class="app-phone__screen"
        />
      </picture>
    </figure>
    """
  end

  @doc "Whether a clip's video and poster are in place."
  def recorded?(name) do
    dir = Application.app_dir(:lumen_viae, "priv/static/images/app/clips")
    Enum.all?(~w(mp4 webp jpg), &File.exists?(Path.join(dir, "#{name}.#{&1}")))
  end
end
