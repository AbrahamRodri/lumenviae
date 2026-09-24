defmodule LumenViaeWeb.Components.Admin do
  @moduledoc """
  The admin console's design vocabulary: the page shell and navigation, the
  panels and metrics pages are assembled from, badges, filter controls, and
  the two small charts the dashboard draws.

  ## Why this does not look like the site

  The public site is parchment, Cinzel and EB Garamond, and gold rules
  around everything. That is right for a page someone reads a paragraph of
  at a time, and wrong for a console: an admin screen is scanned, not read.
  It wants density, alignment, one type family with tabular figures, and
  colour reserved for status so that a red cell means something. Every gold
  rule that decorates a panel is a rule the eye has to discount before it
  can find the number it came for.

  So the admin keeps navy and gold for the navigation shell and the accent,
  and takes a neutral ground, hairline rules and Work Sans for everything
  else. The tokens live in `assets/css/app.css` under `--color-admin-*`.

  Imported globally via `LumenViaeWeb.html_helpers/0`.
  """
  use Phoenix.Component

  alias LumenViae.Rosary.Categories

  @nav_items [
    %{label: "Dashboard", path: "/admin", key: "dashboard", icon: "hero-squares-2x2"},
    %{
      label: "Meditations",
      path: "/admin/meditations",
      key: "meditations",
      icon: "hero-book-open"
    },
    %{
      label: "Sets",
      path: "/admin/meditation-sets",
      key: "sets",
      icon: "hero-rectangle-stack"
    },
    %{label: "Authors", path: "/admin/authors", key: "authors", icon: "hero-user-circle"},
    %{label: "Mysteries", path: "/admin/mysteries", key: "mysteries", icon: "hero-sparkles"},
    %{
      label: "Spoken Rosary",
      path: "/admin/rosary-audio",
      key: "rosary_audio",
      icon: "hero-speaker-wave"
    },
    %{
      label: "Import CSV",
      path: "/admin/meditations/import",
      key: "import",
      icon: "hero-arrow-up-tray"
    }
  ]

  @doc """
  Page shell for every admin screen: the navigation rail, flash messages, a
  sticky page header (title, subtitle, actions), and the page body on the
  console canvas.

  `active` marks the current section: one of "dashboard", "meditations",
  "sets", "authors", "mysteries", "rosary_audio", "import".
  """
  attr :active, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :flash, :map, default: %{}
  attr :max_width, :string, default: "max-w-[1600px]"
  slot :actions
  slot :inner_block, required: true

  def admin_page(assigns) do
    assigns = assign(assigns, :items, @nav_items)

    ~H"""
    <div class="admin-root min-h-screen bg-admin-canvas lg:flex">
      <.admin_rail active={@active} items={@items} />
      <.admin_topbar active={@active} items={@items} />

      <div class="flex-1 min-w-0">
        <LumenViaeWeb.Layouts.flash_group flash={@flash} />

        <header class="sticky top-0 z-20 bg-admin-canvas/95 backdrop-blur border-b border-admin-hairline">
          <div class={[@max_width, "mx-auto px-5 lg:px-8 py-4"]}>
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div class="min-w-0">
                <h1 class="text-xl font-semibold text-admin-ink truncate">{@title}</h1>
                <p :if={@subtitle} class="text-admin-ink-soft text-[0.8125rem] mt-0.5">
                  {@subtitle}
                </p>
              </div>
              <div :if={@actions != []} class="flex flex-wrap items-center gap-2">
                {render_slot(@actions)}
              </div>
            </div>
          </div>
        </header>

        <main class={[@max_width, "mx-auto px-5 lg:px-8 py-6"]}>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  # The permanent navigation rail, from `lg` up.
  attr :active, :string, required: true
  attr :items, :list, required: true

  defp admin_rail(assigns) do
    ~H"""
    <%!-- Pinned to the viewport and never taller than it, so the console has
          exactly one scrollbar: the page's. A rail that scrolls with the page
          means chasing the navigation back to the top; a rail with its own
          overflow means two bars racing each other. --%>
    <nav class="hidden lg:flex lg:flex-col w-56 shrink-0 bg-admin-shell sticky top-0 h-[100dvh] max-h-[100dvh] self-start">
      <div class="px-4 py-5 border-b border-white/10">
        <p class="font-cinzel-decorative text-gold text-sm tracking-[0.18em]">LUMEN VIAE</p>
        <p class="admin-eyebrow text-white/40 mt-1">Console</p>
      </div>

      <div class="flex-1 min-h-0 overflow-y-auto p-2 space-y-0.5">
        <.link
          :for={item <- @items}
          navigate={item.path}
          class={[
            "flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[0.8125rem] transition-colors",
            if(@active == item.key,
              do: "bg-admin-shell-raised text-gold font-semibold",
              else: "text-white/70 hover:bg-white/5 hover:text-white"
            )
          ]}
        >
          <span class={[item.icon, "size-4 shrink-0"]} aria-hidden="true" />
          {item.label}
        </.link>
      </div>

      <div class="p-2 border-t border-white/10 space-y-0.5">
        <.link
          navigate="/"
          class="flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[0.8125rem] text-white/70 hover:bg-white/5 hover:text-white transition-colors"
        >
          <span class="hero-arrow-top-right-on-square size-4 shrink-0" aria-hidden="true" /> View site
        </.link>
        <.logout_form class="flex w-full items-center gap-2.5 px-2.5 py-2 rounded-md text-[0.8125rem] text-white/70 hover:bg-white/5 hover:text-white transition-colors" />
      </div>
    </nav>
    """
  end

  # Below `lg` the rail collapses to a bar with a scrollable section row, so
  # the console stays usable on a phone without a drawer to open.
  attr :active, :string, required: true
  attr :items, :list, required: true

  defp admin_topbar(assigns) do
    ~H"""
    <div class="lg:hidden sticky top-0 z-30 bg-admin-shell">
      <div class="flex items-center justify-between px-4 py-2.5">
        <p class="font-cinzel-decorative text-gold text-xs tracking-[0.18em]">LUMEN VIAE</p>
        <div class="flex items-center gap-3">
          <.link navigate="/" class="text-white/70 hover:text-white text-xs">View site</.link>
          <.logout_form class="text-white/70 hover:text-white text-xs" />
        </div>
      </div>
      <div class="flex gap-1 px-2 pb-2 overflow-x-auto">
        <.link
          :for={item <- @items}
          navigate={item.path}
          class={[
            "px-2.5 py-1.5 rounded-md text-xs whitespace-nowrap transition-colors",
            if(@active == item.key,
              do: "bg-admin-shell-raised text-gold font-semibold",
              else: "text-white/70 hover:bg-white/5"
            )
          ]}
        >
          {item.label}
        </.link>
      </div>
    </div>
    """
  end

  attr :class, :string, required: true

  defp logout_form(assigns) do
    ~H"""
    <form action="/admin/session" method="post">
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <input type="hidden" name="_method" value="delete" />
      <button type="submit" class={@class}>
        <span
          class="hero-arrow-left-on-rectangle size-4 shrink-0 hidden lg:inline"
          aria-hidden="true"
        /> Log out
      </button>
    </form>
    """
  end

  @doc """
  A titled card. Everything on an admin page that is not a metric or a table
  header sits in one of these.

  `flush` drops the body padding, for a panel whose whole body is a table.
  """
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :flush, :boolean, default: false
  attr :class, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section class={[
      "bg-admin-surface border border-admin-hairline rounded-lg shadow-admin overflow-hidden",
      @class
    ]}>
      <header
        :if={@title || @actions != []}
        class="flex flex-wrap items-center justify-between gap-2 px-4 py-3 border-b border-admin-hairline"
      >
        <div class="min-w-0">
          <h2 :if={@title} class="text-[0.9375rem] font-semibold text-admin-ink">{@title}</h2>
          <p :if={@description} class="text-xs text-admin-ink-soft mt-0.5">{@description}</p>
        </div>
        <div :if={@actions != []} class="flex items-center gap-2">{render_slot(@actions)}</div>
      </header>
      <div class={unless @flush, do: "p-4"}>{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  One figure in a metric row: a label, the number, and either a
  period-on-period delta or a line of context under it.

  Give `navigate` and the whole tile becomes the link to the list it counts,
  which is the only reason to put a number on a dashboard at all.

  `tone` colours the figure: "neutral" (default), "accent" for the one
  figure a screen is actually about, "caution" and "danger" for counts that
  represent work outstanding - and both of those fall back to neutral at
  zero, so a healthy console is monochrome.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :navigate, :string, default: nil
  attr :tone, :string, default: "neutral"
  attr :delta, :integer, default: nil
  attr :delta_label, :string, default: nil

  def metric(assigns) do
    assigns = assign(assigns, :tone, resolve_tone(assigns.tone, assigns.value))

    ~H"""
    <.maybe_link
      navigate={@navigate}
      class={[
        "block bg-admin-surface border border-admin-hairline rounded-lg shadow-admin px-4 py-3.5",
        @navigate && "hover:border-admin-hairline-strong hover:shadow-admin-raised transition-all"
      ]}
    >
      <p class="admin-eyebrow">{@label}</p>
      <div class="flex items-baseline gap-2 mt-1.5">
        <span class={["admin-figure", figure_tone(@tone)]}>{@value}</span>
        <.delta_chip :if={@delta} delta={@delta} />
      </div>
      <p :if={@hint || @delta_label} class="text-xs text-admin-ink-faint mt-1 truncate">
        {@hint || @delta_label}
      </p>
    </.maybe_link>
    """
  end

  defp resolve_tone(tone, value) when tone in ["caution", "danger"] do
    if value == 0, do: "positive", else: tone
  end

  defp resolve_tone(tone, _value), do: tone

  defp figure_tone("accent"), do: "text-gold-dark"
  defp figure_tone("caution"), do: "text-caution-strong"
  defp figure_tone("danger"), do: "text-danger-strong"
  defp figure_tone("positive"), do: "text-admin-ink"
  defp figure_tone(_neutral), do: "text-admin-ink"

  attr :delta, :integer, required: true

  defp delta_chip(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-0.5 text-[0.6875rem] font-semibold px-1.5 py-0.5 rounded",
      if(@delta > 0,
        do: "bg-positive-surface text-positive-strong",
        else: "bg-danger-surface text-danger-strong"
      )
    ]}>
      {if @delta > 0, do: "+", else: ""}{@delta}
    </span>
    """
  end

  attr :navigate, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp maybe_link(assigns) do
    ~H"""
    <%= if @navigate do %>
      <.link navigate={@navigate} class={@class}>{render_slot(@inner_block)}</.link>
    <% else %>
      <div class={@class}>{render_slot(@inner_block)}</div>
    <% end %>
    """
  end

  @doc """
  Inline status pill. Tones: "gold", "navy", "gray", "amber", "red",
  "green", "category" (reads a category slug and prints its label).
  """
  attr :tone, :string, default: "gray"
  attr :title, :string, default: nil
  slot :inner_block, required: true

  def admin_badge(assigns) do
    ~H"""
    <span
      title={@title}
      class={[
        "inline-flex items-center px-1.5 py-0.5 text-[0.6875rem] font-medium rounded",
        "whitespace-nowrap align-middle border",
        badge_classes(@tone)
      ]}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_classes("gold"), do: "border-gold/40 bg-gold/10 text-gold-dark"
  defp badge_classes("navy"), do: "border-navy/20 bg-navy/5 text-navy"
  defp badge_classes("amber"), do: "border-caution-border bg-caution-surface text-caution-strong"
  defp badge_classes("red"), do: "border-danger-border bg-danger-surface text-danger-strong"

  defp badge_classes("green"),
    do: "border-positive-border bg-positive-surface text-positive-strong"

  defp badge_classes(_gray),
    do: "border-admin-hairline bg-admin-sunken text-admin-ink-soft"

  @doc """
  A meditation category as a badge, so the same slug never renders two ways.
  """
  attr :category, :string, required: true

  def category_badge(assigns) do
    ~H"""
    <.admin_badge tone="navy">{Categories.label(@category)}</.admin_badge>
    """
  end

  @doc """
  Labeled select for filter forms. `options` is a list of {label, value}
  tuples; when `prompt` is given it renders as the blank "all" option.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list, required: true

  def filter_select(assigns) do
    ~H"""
    <div>
      <label class="admin-eyebrow block mb-1">{@label}</label>
      <select name={@name} class="admin-field">
        <option :if={@prompt} value="" selected={@value in [nil, ""]}>{@prompt}</option>
        <option
          :for={{label, value} <- @options}
          value={value}
          selected={to_string(@value) == to_string(value)}
        >
          {label}
        </option>
      </select>
    </div>
    """
  end

  @doc """
  Labeled debounced text input for filter forms.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""

  def filter_search(assigns) do
    ~H"""
    <div>
      <label class="admin-eyebrow block mb-1">{@label}</label>
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class="admin-field"
        phx-debounce="400"
      />
    </div>
    """
  end

  @doc """
  The bar under a filter form: how many rows are showing, and the way back
  to all of them.
  """
  attr :shown, :integer, required: true
  attr :total, :integer, required: true
  attr :noun, :string, required: true
  attr :filtered, :boolean, required: true
  slot :inner_block

  def filter_summary(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-between gap-2 mt-3 pt-3 border-t border-admin-hairline">
      <p class="text-xs text-admin-ink-soft">
        Showing <span class="font-semibold text-admin-ink">{@shown}</span> of {@total} {@noun}
      </p>
      <div class="flex items-center gap-2">
        {render_slot(@inner_block)}
        <button
          :if={@filtered}
          type="button"
          phx-click="clear_filters"
          class="admin-btn admin-btn-ghost"
        >
          Clear filters
        </button>
      </div>
    </div>
    """
  end

  @doc """
  One labelled control in an admin form: the label, the control itself, and
  an optional line of help under it.

  The control is given as the block so this stays agnostic about whether it
  wraps an input, a textarea, a select or a group of checkboxes - which is
  what keeps every form on the same 6px label gap without a component per
  input type.
  """
  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :required, :boolean, default: false
  attr :class, :string, default: nil
  attr :errors, :list, default: []
  slot :inner_block, required: true

  def field(assigns) do
    ~H"""
    <div class={@class}>
      <label class="block text-[0.8125rem] font-medium text-admin-ink mb-1.5">
        {@label}<span :if={@required} class="text-danger ml-0.5" aria-hidden="true">*</span>
      </label>
      {render_slot(@inner_block)}
      <p :if={@hint} class="text-xs text-admin-ink-faint mt-1">{@hint}</p>
      <p :for={error <- @errors} class="text-xs text-danger-strong mt-1">
        {LumenViaeWeb.CoreComponents.translate_error(error)}
      </p>
    </div>
    """
  end

  @doc """
  A standing note at the top of a page: why this record is not behaving the
  way the curator expects, and what to do about it. Tones: "caution",
  "danger", "notice".
  """
  attr :tone, :string, default: "caution"
  slot :inner_block, required: true

  def callout(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-2.5 rounded-lg border px-4 py-3 mb-5 text-[0.8125rem]",
      callout_classes(@tone)
    ]}>
      <span class={[callout_icon(@tone), "size-4 shrink-0 mt-0.5"]} aria-hidden="true" />
      <div>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  defp callout_classes("danger"),
    do: "border-danger-border bg-danger-surface text-danger-strong"

  defp callout_classes("notice"), do: "border-notice-border bg-notice-surface text-notice"

  defp callout_classes(_caution),
    do: "border-caution-border bg-caution-surface text-caution-strong"

  defp callout_icon("notice"), do: "hero-information-circle"
  defp callout_icon(_warning), do: "hero-exclamation-triangle"

  @doc """
  The row that closes a form: the way back on the left, the commit on the
  right, and a hairline above so it reads as the end of the panel.
  """
  attr :cancel_to, :string, required: true
  attr :cancel_label, :string, default: "Cancel"
  slot :inner_block, required: true

  def form_actions(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 mt-6 pt-4 border-t border-admin-hairline">
      <.link navigate={@cancel_to} class="admin-btn admin-btn-ghost">
        {@cancel_label}
      </.link>
      <div class="flex items-center gap-2">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Muted empty-state message for lists with no results.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "border border-dashed border-admin-hairline-strong rounded-lg py-10 px-6 text-center",
      @class
    ]}>
      <p class="text-[0.8125rem] text-admin-ink-soft">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  @doc """
  A daily series as a column chart.

  `series` is `[%{date: %Date{}, count: integer}]` oldest first. Drawn as
  inline SVG on a 0-100 viewBox so it scales to whatever column it lands in,
  with no chart library and no client-side work.
  """
  attr :series, :list, required: true
  attr :height, :integer, default: 72

  def day_chart(assigns) do
    counts = Enum.map(assigns.series, & &1.count)
    peak = counts |> Enum.max(fn -> 0 end) |> max(1)
    slot_width = 100 / max(length(assigns.series), 1)

    assigns = assign(assigns, peak: peak, slot_width: slot_width, total: Enum.sum(counts))

    ~H"""
    <div>
      <svg
        viewBox={"0 0 100 #{@height}"}
        preserveAspectRatio="none"
        class="w-full block"
        style={"height: #{@height}px"}
        role="img"
        aria-label={"#{@total} completions over the last #{length(@series)} days"}
      >
        <g :for={{point, index} <- Enum.with_index(@series)}>
          <title>{Calendar.strftime(point.date, "%b %-d")}: {point.count}</title>
          <rect
            x={index * @slot_width + @slot_width * 0.15}
            y={@height - bar_height(point.count, @peak, @height)}
            width={@slot_width * 0.7}
            height={bar_height(point.count, @peak, @height)}
            rx="0.6"
            class={if point.count > 0, do: "fill-navy", else: "fill-admin-hairline"}
          />
        </g>
      </svg>
      <div class="flex justify-between text-[0.6875rem] text-admin-ink-faint mt-1">
        <span>{first_label(@series)}</span>
        <span>Peak {@peak}</span>
        <span>{last_label(@series)}</span>
      </div>
    </div>
    """
  end

  # A day with completions always draws something, so a single Rosary on an
  # otherwise empty week is visible rather than rounded away to nothing.
  defp bar_height(0, _peak, _height), do: 1
  defp bar_height(count, peak, height), do: max(count / peak * (height - 2), 2)

  defp first_label([]), do: ""
  defp first_label([point | _]), do: Calendar.strftime(point.date, "%b %-d")

  defp last_label([]), do: ""

  defp last_label(series),
    do: series |> List.last() |> Map.fetch!(:date) |> then(&Calendar.strftime(&1, "%b %-d"))

  @doc """
  A ranked list as labelled bars: the shape a "top N by count" answer should
  take, rather than a column of numbers the eye has to compare by reading.

  `rows` is `[%{label:, count:, sublabel:, navigate:}]`, highest first.
  """
  attr :rows, :list, required: true

  def bar_list(assigns) do
    peak = assigns.rows |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end) |> max(1)
    assigns = assign(assigns, :peak, peak)

    ~H"""
    <ol class="space-y-2.5">
      <li :for={row <- @rows} class="group">
        <div class="flex items-baseline justify-between gap-3">
          <.maybe_link
            navigate={row[:navigate]}
            class="text-[0.8125rem] text-admin-ink truncate group-hover:text-navy"
          >
            {row.label}
          </.maybe_link>
          <span class="text-[0.8125rem] font-semibold text-admin-ink shrink-0">{row.count}</span>
        </div>
        <div class="h-1.5 bg-admin-sunken rounded-full mt-1 overflow-hidden">
          <div class="h-full bg-navy rounded-full" style={"width: #{row.count / @peak * 100}%"}></div>
        </div>
        <p :if={row[:sublabel]} class="text-[0.6875rem] text-admin-ink-faint mt-0.5">
          {row.sublabel}
        </p>
      </li>
    </ol>
    """
  end
end
