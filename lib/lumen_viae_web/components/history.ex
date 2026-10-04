defmodule LumenViaeWeb.Components.History do
  @moduledoc """
  The History panel on the console's edit pages (meditation, set, mystery,
  author): every change to the record, newest first, with who made it, the
  fields it changed and a way to put an earlier version back.

  The page owns the state, as every console page does: it assigns
  `@history` from `LumenViae.Rosary.list_history/2` and
  `@restorable` from `LumenViae.Rosary.restorable_fields/1`, and handles
  the `"restore_version"` event with `LumenViae.Rosary.restore_version/3`,
  reassigning both afterwards. This module draws the panel and works out
  what changed between two snapshots, which is presentation.

  Called fully qualified: `<LumenViaeWeb.Components.History.history_panel ...>`.
  """
  use Phoenix.Component

  import LumenViaeWeb.Components.Admin

  alias LumenViae.CentralTime

  # Never shown as a change: the key is the record's identity, and the
  # rest move on every write or are written by the pipeline, not a person.
  @hidden_fields ~w(id inserted_at updated_at tts_annotations)

  # A string longer than this, or with a line break, is shown as a word
  # diff rather than as "before" and "after" in full.
  @long_text 80

  @doc """
  The panel. `history` is `Rosary.list_history/2`'s list; `restorable` the
  field names a restore puts back. The newest version is the record as it
  stands, so it has no Restore button.
  """
  attr :history, :list, required: true
  attr :restorable, :list, required: true

  def history_panel(assigns) do
    assigns = assign(assigns, :entries, entries(assigns.history))

    ~H"""
    <.panel
      title="History"
      description="Every change to this record, newest first. Restoring puts back the fields this form edits, as a new change you can undo."
      class="mt-5"
    >
      <.empty_state :if={@entries == []}>
        No changes recorded yet.
      </.empty_state>

      <ol class="divide-y divide-admin-hairline -my-2">
        <li :for={{entry, index} <- Enum.with_index(@entries)} class="py-3">
          <div class="flex flex-wrap items-baseline justify-between gap-2">
            <div class="flex flex-wrap items-baseline gap-2 min-w-0">
              <.admin_badge tone={action_tone(entry.type)}>{action_label(entry.action)}</.admin_badge>
              <span class="text-[0.8125rem] text-admin-ink">{CentralTime.format_short(entry.at)}</span>
              <span class="text-xs text-admin-ink-soft">{entry.by || "an operator's shell"}</span>
              <.admin_badge :if={index == 0} tone="green">Current</.admin_badge>
            </div>
            <button
              :if={index > 0 and entry.type != :destroy and restores_anything?(entry, @restorable)}
              type="button"
              phx-click="restore_version"
              phx-value-id={entry.id}
              data-confirm="Put this record back as it stood after this change? The restore is itself recorded, and can be undone the same way."
              class="admin-btn admin-btn-ghost"
            >
              Restore
            </button>
          </div>

          <p :if={entry.diff == :unrecorded} class="text-xs text-admin-ink-faint mt-1.5">
            The first change on record. This record is older than its history, so what it changed
            from was not kept; restoring this version puts back the record as it stood after it.
          </p>

          <p
            :if={entry.diff == [] and entry.type != :create}
            class="text-xs text-admin-ink-faint mt-1.5"
          >
            No field this panel shows changed.
          </p>

          <dl :if={is_list(entry.diff) and entry.diff != []} class="mt-2 space-y-2">
            <div :for={change <- entry.diff} class="grid md:grid-cols-[10rem_1fr] gap-x-3 gap-y-0.5">
              <dt class="admin-eyebrow pt-0.5">{field_label(change.field)}</dt>
              <dd class="text-[0.8125rem] text-admin-ink min-w-0">
                <.change_value change={change} />
              </dd>
            </div>
          </dl>
        </li>
      </ol>
    </.panel>
    """
  end

  attr :change, :map, required: true

  defp change_value(%{change: %{words: words}} = assigns) when is_list(words) do
    assigns = assign(assigns, :words, words)

    ~H"""
    <p class="whitespace-pre-line leading-relaxed">
      <span
        :for={{op, text} <- @words}
        class={word_class(op)}
      >{text}</span>
    </p>
    """
  end

  defp change_value(assigns) do
    ~H"""
    <span :if={@change.before != nil} class="line-through text-danger-strong">
      {display(@change.before)}
    </span>
    <span :if={@change.before != nil} class="text-admin-ink-faint" aria-hidden="true">-&gt;</span>
    <span class="text-positive-strong">{display(@change.after)}</span>
    """
  end

  defp word_class(:eq), do: nil
  defp word_class(:del), do: "line-through bg-danger-surface text-danger-strong"
  defp word_class(:ins), do: "bg-positive-surface text-positive-strong"

  @doc """
  The history as panel entries: each version with `:diff`, the fields that
  differ from the version before it. A create lists every field it set; a
  destroy lists nothing, since it changed no field; and an update with no
  version before it is `:unrecorded`, because the record predates the
  history and what it changed from is unknown.
  """
  def entries(history) do
    older = Enum.drop(history, 1) ++ [nil]

    history
    |> Enum.zip(older)
    |> Enum.map(fn {version, previous} ->
      Map.put(version, :diff, diff(version, previous))
    end)
  end

  defp diff(%{type: :destroy}, _previous), do: []

  # The oldest version on record is an update when the record predates the
  # paper trail: what it changed from was never written down.
  defp diff(%{type: :update}, nil), do: :unrecorded

  defp diff(%{snapshot: snapshot}, previous) do
    before = if previous, do: previous.snapshot, else: %{}

    snapshot
    |> Map.keys()
    |> Enum.reject(&(&1 in @hidden_fields))
    |> Enum.sort()
    |> Enum.flat_map(fn field ->
      old = Map.get(before, field)
      new = Map.get(snapshot, field)

      cond do
        old == new -> []
        previous == nil and blank?(new) -> []
        true -> [change(field, old, new)]
      end
    end)
  end

  defp change(field, old, new) when is_binary(old) and is_binary(new) do
    if long?(old) or long?(new) do
      %{field: field, before: old, after: new, words: word_diff(old, new)}
    else
      %{field: field, before: old, after: new}
    end
  end

  defp change(field, old, new), do: %{field: field, before: old, after: new}

  defp long?(text), do: String.length(text) > @long_text or String.contains?(text, "\n")

  @doc """
  A word-level diff of two texts as `[{:eq | :del | :ins, text}]`, keeping
  the whitespace, so a one-word correction to a long passage reads as that
  word rather than as two copies of the passage.
  """
  def word_diff(old, new) do
    old
    |> tokens()
    |> List.myers_difference(tokens(new))
    |> Enum.map(fn {op, words} -> {op, Enum.join(words)} end)
  end

  # Words and the whitespace after them, so joining puts the text back.
  defp tokens(text), do: Regex.scan(~r/\S+\s*|\s+/, text) |> List.flatten()

  defp restores_anything?(%{snapshot: snapshot}, restorable) do
    Enum.any?(restorable, &Map.has_key?(snapshot, &1))
  end

  defp blank?(value), do: value in [nil, "", []]

  defp display(nil), do: "(empty)"
  defp display(""), do: "(empty)"
  defp display([]), do: "(none)"
  defp display(list) when is_list(list), do: Enum.map_join(list, ", ", &display/1)
  defp display(value) when is_binary(value), do: value
  defp display(value), do: to_string(value)

  defp action_tone(:create), do: "green"
  defp action_tone(:destroy), do: "red"
  defp action_tone(_update), do: "gray"

  @doc "An action name as the panel shows it: `:record_artwork` is \"Record artwork\"."
  def action_label(action) do
    action |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @doc "A field name as the panel shows it: `\"mystery_id\"` is \"Mystery\"."
  def field_label(field) do
    field |> String.replace_suffix("_id", "") |> String.replace("_", " ") |> String.capitalize()
  end
end
