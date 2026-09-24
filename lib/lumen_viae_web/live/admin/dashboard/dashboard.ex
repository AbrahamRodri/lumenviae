defmodule LumenViaeWeb.Live.Admin.Dashboard do
  @moduledoc """
  The admin landing screen: what the public is being served, what is
  standing between the library and being finished, and whether anyone is
  praying it.

  Two rules shape what appears here.

  **Health reports on live content only.** A set hidden from the public
  because one of its meditations is archived is not a set with a missing
  painting - it is a set nobody can reach, which is one problem, listed
  once, under its own heading. Counting it again under every other heading
  turned the checklist into a list of things that did not need doing.

  **Every number is a link.** A count with no way through to the rows it
  counts is trivia. Each metric and each health row lands on the admin list
  already filtered to exactly the rows in question.
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.CentralTime
  alias LumenViae.Curation.RosaryAudioGeneration
  alias LumenViae.Rosary
  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Live.Meditations.Sets.Filtering, as: SetFiltering

  @chart_days 30
  @recent_completions 8

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:rosary_audio_missing, 0)
     |> load()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, socket |> load() |> put_flash(:info, "Refreshed.")}
  end

  # The spoken Rosary's coverage is one HEAD per clip against S3, far
  # slower than every query above put together, so it lands after the page
  # is up and adds its row to the health list when it does. A bucket that
  # cannot be asked counts nothing: "unknown" is not "missing".
  def handle_async(:rosary_audio, {:ok, coverage}, socket) do
    missing =
      coverage
      |> Enum.flat_map(fn {_voice, entries} -> entries end)
      |> Enum.count(&(&1.status == :missing))

    {:noreply, socket |> assign(:rosary_audio_missing, missing) |> assign_health()}
  end

  def handle_async(:rosary_audio, {:exit, _reason}, socket), do: {:noreply, socket}

  defp load(socket) do
    sets = Rosary.list_meditation_sets()
    hidden_ids = Rosary.hidden_meditation_set_ids()
    set_stats = Rosary.meditation_set_stats()
    mysteries = Rosary.list_mysteries()
    mystery_counts = Rosary.active_meditation_counts_by_mystery()
    authors = Rosary.list_authors()

    live_sets = Enum.reject(sets, &MapSet.member?(hidden_ids, &1.id))
    hidden_sets = Enum.filter(sets, &MapSet.member?(hidden_ids, &1.id))

    content_health =
      build_health(live_sets, hidden_sets, set_stats, mysteries, mystery_counts, authors)

    socket
    |> assign(:content_health, content_health)
    |> assign_health()
    |> start_rosary_audio_check()
    |> assign(:library, %{
      live_sets: length(live_sets),
      total_sets: length(sets),
      hidden_sets: length(hidden_sets),
      meditations: Rosary.count_meditations(),
      archived: Rosary.count_archived_meditations(),
      mysteries: length(mysteries),
      authors: length(authors)
    })
    |> assign(:coverage, coverage(live_sets, set_stats))
    |> assign(:completions, Rosary.completion_summary())
    |> assign(:completion_days, Rosary.completions_by_day(@chart_days))
    |> assign(:top_sets, Rosary.get_completions_by_set(days: @chart_days) |> Enum.take(6))
    |> assign(:recent_completions, Rosary.get_recent_completions(@recent_completions))
    |> assign(:locations, Rosary.completion_locations(@chart_days))
    |> assign(:refreshed_at, DateTime.utc_now())
  end

  defp start_rosary_audio_check(socket) do
    if connected?(socket) do
      start_async(socket, :rosary_audio, fn -> RosaryAudioGeneration.coverage() end)
    else
      socket
    end
  end

  defp assign_health(socket) do
    rosary_audio = %{
      count: socket.assigns.rosary_audio_missing,
      tone: "danger",
      label: "Spoken Rosary clips missing",
      description:
        "Prayers, announcements or verses not recorded in a narration voice. " <>
          "The app skips them, and will not pray aloud at all without a Hail Mary.",
      link: ~p"/admin/rosary-audio?show=missing",
      names: []
    }

    health =
      [rosary_audio | socket.assigns.content_health]
      |> Enum.reject(&(&1.count == 0))
      |> Enum.sort_by(&{tone_rank(&1.tone), -&1.count})

    socket
    |> assign(:health, health)
    |> assign(:open_issues, Enum.sum(Enum.map(health, & &1.count)))
  end

  # Only rows that represent work to do. Purely informational counts (how
  # many sets are hidden, how many meditations are archived) live in the
  # metric row instead, so that "0 issues" means the checklist is genuinely
  # empty rather than permanently showing a number nobody can drive to zero.
  defp build_health(live_sets, hidden_sets, set_stats, mysteries, mystery_counts, authors) do
    [
      %{
        count: length(Rosary.public_meditation_ids_missing_audio()),
        tone: "danger",
        label: "Meditations without narration",
        description:
          "Active meditations in a live set with no audio file. The app has nothing to play.",
        link: ~p"/admin/meditations?audio=without&status=active",
        names: []
      },
      %{
        count: length(Rosary.meditation_ids_missing_a_voice()),
        tone: "caution",
        label: "Meditations missing a voice",
        description:
          "Have an audio file but no recording in every narration voice. " <>
            "Run regenerate_audio --all --only-missing to fill the gaps.",
        link: ~p"/admin/meditations?audio=with&status=active",
        names: []
      },
      %{
        count: count_sets(live_sets, &(SetFiltering.artwork_state(&1) == :missing)),
        tone: "caution",
        label: "Live sets without artwork",
        description: "No painting of their own and no linked author portrait to fall back on.",
        link: ~p"/admin/meditation-sets?artwork=missing",
        names: names(live_sets, &(SetFiltering.artwork_state(&1) == :missing))
      },
      %{
        count: count_sets(live_sets, &(SetFiltering.artwork_state(&1) == :unpublishable)),
        tone: "caution",
        label: "Artwork uploaded but not served",
        description: "A painting is saved but still needs a description and a licence.",
        link: ~p"/admin/meditation-sets?artwork=unpublishable",
        names: names(live_sets, &(SetFiltering.artwork_state(&1) == :unpublishable))
      },
      %{
        count: count_sets(live_sets, &(meditation_count(&1, set_stats) == 0)),
        tone: "danger",
        label: "Empty sets",
        description: "Live sets with no meditations at all.",
        link: ~p"/admin/meditation-sets?completeness=empty",
        names: names(live_sets, &(meditation_count(&1, set_stats) == 0))
      },
      %{
        count: count_sets(live_sets, &partial?(&1, set_stats)),
        tone: "caution",
        label: "Partially filled sets",
        description: "Live sets with the wrong meditation count for their category.",
        link: ~p"/admin/meditation-sets?completeness=incomplete",
        names: names(live_sets, &partial?(&1, set_stats))
      },
      %{
        count: count_sets(live_sets, &(&1.labels == [])),
        tone: "caution",
        label: "Live sets without labels",
        description: "The app files these under \"More\" instead of a filter chip.",
        link: ~p"/admin/meditation-sets?label=none",
        names: names(live_sets, &(&1.labels == []))
      },
      %{
        count: length(hidden_sets),
        tone: "caution",
        label: "Sets hidden from the public",
        description:
          "Withdrawn from the site and the app because they contain an archived meditation.",
        link: ~p"/admin/meditation-sets?visibility=hidden",
        names: Enum.map(hidden_sets, & &1.name)
      },
      %{
        count: Rosary.count_meditations_not_in_any_set(),
        tone: "caution",
        label: "Meditations in no set",
        description: "Active meditations that never appear in the app or on the site.",
        link: ~p"/admin/meditations?set=none",
        names: []
      },
      %{
        count: Enum.count(mysteries, &(Map.get(mystery_counts, &1.id, 0) == 0)),
        tone: "caution",
        label: "Mysteries without a meditation",
        description: "Nothing has been written for these mysteries yet.",
        link: ~p"/admin/mysteries",
        names: mysteries |> Enum.filter(&(Map.get(mystery_counts, &1.id, 0) == 0)) |> names()
      },
      %{
        count: Enum.count(authors, &(not Artwork.publishable?(&1))),
        tone: "caution",
        label: "Authors without a served portrait",
        description: "Their sets cannot inherit a portrait until one is uploaded and described.",
        link: ~p"/admin/authors",
        names: authors |> Enum.filter(&(not Artwork.publishable?(&1))) |> names()
      }
    ]
    |> Enum.reject(&(&1.count == 0))
    |> Enum.sort_by(&{tone_rank(&1.tone), -&1.count})
  end

  defp tone_rank("danger"), do: 0
  defp tone_rank(_caution), do: 1

  defp count_sets(sets, predicate), do: Enum.count(sets, predicate)
  defp names(records), do: Enum.map(records, & &1.name)
  defp names(sets, predicate), do: sets |> Enum.filter(predicate) |> names()

  defp meditation_count(set, stats), do: SetFiltering.meditation_count(set, stats)

  defp partial?(set, stats) do
    count = meditation_count(set, stats)
    count > 0 and count != Rosary.expected_meditation_count(set.category)
  end

  # How much finished, publishable content each category actually has. This
  # is the question a curator plans from - "which category is thinnest?" -
  # and no list view answers it.
  defp coverage(live_sets, stats) do
    by_category = Enum.group_by(live_sets, & &1.category)

    Enum.map(Categories.options(), fn {label, slug} ->
      sets = Map.get(by_category, slug, [])

      %{
        label: label,
        slug: slug,
        sets: length(sets),
        complete:
          Enum.count(
            sets,
            &(meditation_count(&1, stats) == Rosary.expected_meditation_count(slug))
          ),
        illustrated: Enum.count(sets, &(SetFiltering.artwork_state(&1) == :served)),
        narrated: Enum.count(sets, &fully_narrated?(&1, stats))
      }
    end)
  end

  # A set with no membership rows has no stats entry at all, so this has to
  # answer for a missing key rather than assume one.
  defp fully_narrated?(set, stats) do
    case Map.get(stats, set.id) do
      %{meditation_count: count, audio_count: audio} when count > 0 -> audio == count
      _empty_or_missing -> false
    end
  end

  ## Presentation helpers used by the template

  @doc """
  The change between a trailing window and the window before it, or nil when
  there is nothing to compare against - a first week with no prior week is
  not a hundred per cent rise.
  """
  def delta(_current, 0), do: nil
  def delta(current, previous), do: current - previous

  def delta_label(_current, 0), do: "No prior period"
  def delta_label(_current, previous), do: "#{previous} in the period before"

  def format_time(datetime), do: CentralTime.format_short(datetime)

  @doc """
  Where a completion came from, or a plain note that nothing was recorded.

  A place is attached by a best-effort lookup, so "Not recorded" is an
  ordinary outcome rather than a fault: the lookup can be switched off, the
  address can be one no provider can place, or the row can predate any of
  this.
  """
  def place(completion) do
    [completion.city, completion.region, completion.country]
    |> place_parts()
    |> Enum.join(", ")
    |> case do
      "" -> "Not recorded"
      place -> place
    end
  end

  @doc """
  How a completion was reported. Rows written before a source was stored
  say so plainly rather than being labelled as one surface or the other.
  """
  def source_label("web"), do: "Website"
  def source_label("ios"), do: "iOS app"
  def source_label(_unrecorded), do: "Not recorded"

  @doc """
  A flag for a country code, or nil.

  Regional indicator symbols: two letters mapped into U+1F1E6..U+1F1FF,
  which every platform this console is read on renders as a flag. Cheaper
  than shipping an image for every country, and it degrades to two boxed
  letters rather than to nothing.
  """
  def flag(code) when is_binary(code) do
    letters = code |> String.trim() |> String.upcase() |> String.to_charlist()

    case letters do
      [a, b] when a in ?A..?Z and b in ?A..?Z ->
        List.to_string([a - ?A + 0x1F1E6, b - ?A + 0x1F1E6])

      _not_a_country_code ->
        nil
    end
  end

  def flag(_other), do: nil

  @doc """
  A city named with enough around it to be the right city - "Paris,
  Texas" is not "Paris, France", and a bare city name cannot tell you
  which one you are looking at.

  A region that merely repeats the city is dropped. City states and capital
  regions are common enough that leaving it in produces "Sao Paulo, Sao
  Paulo" and "Singapore, Singapore" as a matter of course.
  """
  def city_label(%{city: city, region: region}) do
    [city, region] |> place_parts() |> Enum.join(", ")
  end

  # Blank parts removed, and any part that just repeats the one before it.
  defp place_parts(parts) do
    parts
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.dedup()
  end

  @doc """
  How much of the period the location figures actually cover, as a
  sentence. Nothing below is a ranking of Rosaries; it is a ranking of the
  ones a lookup could place, and that is worth saying next to it rather
  than in a footnote nobody reads.
  """
  def coverage_note(%{located: 0, total: 0}), do: "No completions in this period."

  def coverage_note(%{located: 0, total: total}) do
    "None of the #{total} completions in this period have a place recorded."
  end

  def coverage_note(%{located: located, total: total}) do
    "#{located} of #{total} completions in this period have a place recorded."
  end

  @doc """
  The web-and-app split, as `[{label, count}]`, largest first.

  Completions recorded before a source was stored answer to `nil` and are
  shown as "Unknown" rather than being dropped, because dropping them makes
  the split add up to less than the total for no stated reason.
  """
  def source_rows(sources) do
    sources
    |> Enum.map(fn
      {"web", count} -> {"Website", count}
      {"ios", count} -> {"iOS app", count}
      {_unrecorded, count} -> {"Unknown", count}
    end)
    |> Enum.reduce(%{}, fn {label, count}, acc -> Map.update(acc, label, count, &(&1 + count)) end)
    |> Enum.sort_by(fn {_label, count} -> -count end)
  end

  @doc """
  Aloud or silently, as `[{label, count}]`, largest first. Rows from
  before the question was asked, or from a build that does not answer it,
  are "Not reported" rather than silently counted as silent.
  """
  def prayed_aloud_rows(counts) do
    counts
    |> Enum.map(fn
      {true, count} -> {"Prayed aloud", count}
      {false, count} -> {"Read silently", count}
      {nil, count} -> {"Not reported", count}
    end)
    |> Enum.sort_by(fn {_label, count} -> -count end)
  end

  def health_tone_classes("danger"), do: "bg-danger-surface text-danger-strong"
  def health_tone_classes(_caution), do: "bg-caution-surface text-caution-strong"

  @doc """
  A few of the affected names, so a row says *which* sets it means without
  the reader having to click through to find out.
  """
  def names_preview([]), do: nil

  def names_preview(names) do
    shown = Enum.take(names, 4)
    rest = length(names) - length(shown)
    preview = Enum.join(shown, ", ")

    if rest > 0, do: "#{preview} and #{rest} more", else: preview
  end
end
