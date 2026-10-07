defmodule LumenViaeWeb.CoreComponents do
  @moduledoc """
  Components shared by the whole application: the flash notice, icons, the
  show and hide JS helpers, error translation, and the public site's
  ornaments (`sacred_divider/1`, `gold_cta/1`, `arch_frame/1`, the medallions).

  The flash notice comes in the console's vocabulary and in the public
  site's (`variant`). See `docs/ARCHITECTURE.md` for the tokens.
  """
  use Phoenix.Component
  use Gettext, backend: LumenViaeWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  Two looks, one per side of the app: `variant={:admin}` (the default) in the
  console's tokens, `variant={:public}` in the site's parchment, navy and
  Garamond. Never cross them.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} variant={:public} />
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :variant, :atom, default: :admin, values: [:admin, :public]
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(%{variant: :public} = assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed z-50 inset-x-4 bottom-[calc(1rem+env(safe-area-inset-bottom))] sm:inset-x-auto sm:bottom-auto sm:top-28 sm:right-6 sm:w-96 cursor-pointer"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 rounded-xl border border-gold/50 border-l-4 bg-parchment px-4 py-3 shadow-ornate font-garamond text-base text-brown",
        @kind == :info && "border-l-navy",
        @kind == :error && "border-l-rubric"
      ]}>
        <div class="min-w-0 flex-1">
          <p :if={@title} class="font-cinzel text-sm tracking-wide text-navy">{@title}</p>
          <p>{msg}</p>
        </div>
        <button
          type="button"
          class="shrink-0 -m-2 inline-flex size-11 items-center justify-center text-brown-light hover:text-navy cursor-pointer"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark-solid" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 w-80 sm:w-96 max-w-[calc(100vw-2rem)] cursor-pointer"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 rounded-lg border border-admin-hairline border-l-4 bg-admin-surface px-4 py-3 shadow-admin-raised font-admin text-[0.8125rem] text-admin-ink",
        @kind == :info && "border-l-notice",
        @kind == :error && "border-l-danger"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-information-circle-mini"
          class="size-5 shrink-0 text-notice"
        />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-circle-mini"
          class="size-5 shrink-0 text-danger"
        />
        <div class="min-w-0 flex-1">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p class={[@title && "text-admin-ink-soft"]}>{msg}</p>
        </div>
        <button
          type="button"
          class="group shrink-0 cursor-pointer"
          aria-label={gettext("close")}
        >
          <.icon
            name="hero-x-mark-solid"
            class="size-4 text-admin-ink-faint group-hover:text-admin-ink-soft"
          />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders the app's ornament divider: fading gold hairlines flanking two
  rotated diamonds and a small Latin cross. The shared Catholic visual
  vocabulary of the iOS app, translated to markup.

  ## Examples

      <.sacred_divider />
      <.sacred_divider cross={false} class="my-12" />
  """
  attr :cross, :boolean, default: true
  attr :class, :string, default: nil
  attr :rest, :global

  def sacred_divider(assigns) do
    ~H"""
    <div
      class={["flex items-center justify-center gap-2.5 my-8", @class]}
      aria-hidden="true"
      {@rest}
    >
      <span class="h-px w-full max-w-40 bg-gradient-to-r from-transparent to-gold/60"></span>
      <span class="w-1.5 h-1.5 rotate-45 bg-gold/80 shrink-0"></span>
      <svg :if={@cross} viewBox="0 0 9 13" class="w-2.5 h-3.5 fill-gold/90 shrink-0">
        <path d="M3.24 0 H5.76 V2.64 H9 V5.16 H5.76 V13 H3.24 V5.16 H0 V2.64 H3.24 Z" />
      </svg>
      <span class="w-1.5 h-1.5 rotate-45 bg-gold/80 shrink-0"></span>
      <span class="h-px w-full max-w-40 bg-gradient-to-l from-transparent to-gold/60"></span>
    </div>
    """
  end

  @doc """
  The app's primary call to action: a gold capsule in engraved caps, led by
  the hand-drawn Latin cross. Renders a link when `navigate`/`href` is given,
  a button otherwise. One filled gold shape per screen region.

  ## Examples

      <.gold_cta navigate="/mysteries/joyful">Begin Praying</.gold_cta>
      <.gold_cta href={@app_store_url} cross={false}>Download the App</.gold_cta>
  """
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :cross, :boolean, default: true
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(target rel type disabled aria-label)
  slot :inner_block, required: true

  def gold_cta(assigns) do
    ~H"""
    <.link :if={@navigate} navigate={@navigate} class={["btn-gold", @class]} {@rest}>
      <.latin_cross :if={@cross} />
      {render_slot(@inner_block)}
    </.link>
    <a :if={!@navigate && @href} href={@href} class={["btn-gold", @class]} {@rest}>
      <.latin_cross :if={@cross} />
      {render_slot(@inner_block)}
    </a>
    <button :if={!@navigate && !@href} class={["btn-gold", @class]} {@rest}>
      <.latin_cross :if={@cross} />
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp latin_cross(assigns) do
    ~H"""
    <svg viewBox="0 0 10 14" class="w-2.5 h-3.5 fill-current shrink-0" aria-hidden="true">
      <path d="M3.6 0 H6.4 V2.8 H10 V5.6 H6.4 V14 H3.6 V5.6 H0 V2.8 H3.6 Z" />
    </svg>
    """
  end

  @doc """
  Frames sacred artwork in a gothic lancet arch with a double gold hairline,
  the app's signature image treatment. Reserve it for devotional paintings
  and portraits; photographs and screenshots stay rectangular.

  The clip path `#lancet-arch` is defined once in root.html.heex.

  ## Examples

      <.arch_frame src="/images/pngs/queen-of-heaven-white-bg.jpg" alt="Queen of Heaven" />
      <.arch_frame src={...} alt={...} class="w-72" img_class="object-top" />
  """
  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :class, :string, default: nil
  attr :img_class, :string, default: nil
  attr :srcset, :string, default: nil, doc: "Lighter copies of `src` (WebP, say), as a srcset"
  attr :sizes, :string, default: nil, doc: "The width the frame is drawn at, for `srcset`"
  attr :rest, :global

  def arch_frame(assigns) do
    ~H"""
    <div class={["relative aspect-[10/13]", @class]} {@rest}>
      <img
        src={@src}
        srcset={@srcset}
        sizes={@sizes}
        alt={@alt}
        class={["absolute inset-0 w-full h-full object-cover", @img_class]}
        style="clip-path: url(#lancet-arch)"
      />
      <svg
        viewBox="0 0 100 130"
        preserveAspectRatio="none"
        class="absolute inset-0 w-full h-full pointer-events-none"
        aria-hidden="true"
      >
        <path
          d="M 0.5 129.5 L 0.5 36.4 Q 3.5 13.8 50 0.7 Q 96.5 13.8 99.5 36.4 L 99.5 129.5"
          fill="none"
          stroke="var(--color-gold)"
          stroke-opacity="0.55"
          stroke-width="1"
          vector-effect="non-scaling-stroke"
        />
        <path
          d="M 3.5 129.5 L 3.5 38 Q 6.3 17.2 50 4.8 Q 93.7 17.2 96.5 38 L 96.5 129.5"
          fill="none"
          stroke="var(--color-gold)"
          stroke-opacity="0.25"
          stroke-width="0.5"
          vector-effect="non-scaling-stroke"
        />
      </svg>
    </div>
    """
  end

  @doc """
  Renders a religious medallion or symbol image.

  ## Examples

      <.medallion type="holy_family" />
      <.medallion type="crucifix" size="large" />
      <.medallion type="deo_gratias" />
  """
  attr :type, :string,
    required: true,
    values: ["holy_family", "crucifix", "pax", "deo_gratias", "saint_benedict"]

  attr :size, :string, default: "medium", values: ["small", "medium", "large"]
  attr :class, :string, default: nil
  attr :rest, :global

  def medallion(assigns) do
    assigns =
      assigns
      |> assign(:image, medallion_image(assigns.type))
      |> assign(:size_class, medallion_size_class(assigns.size))
      |> assign(:sizes, medallion_sizes(assigns.type, assigns.size))

    ~H"""
    <div class={["flex justify-center items-center", @class]} {@rest}>
      <.medallion_img image={@image} sizes={@sizes} class={["h-auto", @size_class]} />
    </div>
    """
  end

  # Each medallion's file and pixel size, so the browser can reserve its space
  # before it loads. Only the crucifix has lighter WebP copies; see
  # docs/IMAGES.md.
  defp medallion_image("holy_family"),
    do: %{src: "/images/pngs/holy-family.png", width: 474, height: 287}

  defp medallion_image("crucifix"),
    do: %{
      src: "/images/pngs/crucifix.png",
      width: 322,
      height: 321,
      srcset: "/images/pngs/crucifix-160.webp 160w, /images/pngs/crucifix-256.webp 256w"
    }

  defp medallion_image("pax"),
    do: %{src: "/images/pngs/olive-branch-pax.png", width: 591, height: 422}

  defp medallion_image("deo_gratias"),
    do: %{src: "/images/pngs/deo-gratias.png", width: 474, height: 266}

  defp medallion_image("saint_benedict"),
    do: %{src: "/images/pngs/saint-benedict-symbol.png", width: 150, height: 150}

  # What `medallion_size_class/1` draws, for the srcset's `sizes`.
  defp medallion_sizes("crucifix", "small"), do: "(min-width: 768px) 48px, 40px"
  defp medallion_sizes("crucifix", "medium"), do: "(min-width: 768px) 128px, 112px"
  defp medallion_sizes("crucifix", "large"), do: "(min-width: 768px) 256px, 192px"
  defp medallion_sizes(_type, _size), do: nil

  attr :image, :map, required: true
  attr :sizes, :string, default: nil
  attr :class, :any, default: nil

  defp medallion_img(assigns) do
    ~H"""
    <img
      src={@image.src}
      srcset={@image[:srcset]}
      sizes={@sizes}
      width={@image.width}
      height={@image.height}
      alt=""
      class={@class}
    />
    """
  end

  defp medallion_size_class("small"), do: "w-10 md:w-12"
  defp medallion_size_class("medium"), do: "w-28 md:w-32"
  defp medallion_size_class("large"), do: "w-48 md:w-64"

  @doc """
  Renders a religious medallion with a light circular background.
  Use this for dark medallion images that need contrast on dark backgrounds.

  ## Examples

      <.medallion_bg type="holy_family" />
      <.medallion_bg type="pax" size="large" />
      <.medallion_bg type="saint_benedict" size="small" />
  """
  attr :type, :string,
    required: true,
    values: ["holy_family", "crucifix", "pax", "deo_gratias", "saint_benedict"]

  attr :size, :string, default: "medium", values: ["small", "medium", "large"]
  attr :class, :string, default: nil
  attr :rest, :global

  def medallion_bg(assigns) do
    assigns =
      assigns
      |> assign(:image, medallion_image(assigns.type))
      |> assign(:size_class, medallion_size_class(assigns.size))
      |> assign(:sizes, medallion_sizes(assigns.type, assigns.size))
      |> assign(:padding_class, medallion_bg_padding(assigns.size))

    ~H"""
    <div class={["flex justify-center items-center", @class]} {@rest}>
      <div class={["bg-cream rounded-full", @padding_class]}>
        <.medallion_img image={@image} sizes={@sizes} class={["h-auto", @size_class]} />
      </div>
    </div>
    """
  end

  defp medallion_bg_padding("small"), do: "p-2"
  defp medallion_bg_padding("medium"), do: "p-4"
  defp medallion_bg_padding("large"), do: "p-6"

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(LumenViaeWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(LumenViaeWeb.Gettext, "errors", msg, opts)
    end
  end
end
