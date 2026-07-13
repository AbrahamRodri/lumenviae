defmodule LumenViae.Audio.TtsText do
  @moduledoc """
  Prepares meditation content for ElevenLabs narration.

  Stored meditation content is plain curated text: it is rendered verbatim
  (whitespace-pre-wrap) and must never contain narration markup. Pause
  control therefore happens in two steps that keep markup out of the
  database entirely:

    * `extract_pauses/1` runs at import time. It strips `{pause:N}` markers
      (N in seconds, decimals allowed) from the curated text and returns the
      clean content to store plus a list of annotations, maps of
      `%{"offset" => grapheme_offset_into_clean_content, "seconds" => n}`,
      persisted in `meditations.tts_annotations`.

    * `to_speech_text/3` runs at audio-generation time. It converts each
      paragraph break in the clean content into an SSML break tag using the
      configured default (`config :lumen_viae, :tts_paragraph_break_seconds`)
      and inserts the annotated pauses at their recorded offsets. An
      annotation adjacent to a paragraph break replaces that break's default
      pause instead of stacking a second pause onto it.

  ElevenLabs honors `<break time="Ns" />` on all current models except
  Eleven V3 (including eleven_multilingual_v2, which this app uses) and caps
  pauses at 3 seconds, so every duration is clamped to that maximum.

  ## Whitespace around stripped markers

  Removing a marker must leave the stored text reading naturally, so the
  whitespace on either side of it collapses to whichever separator was
  already strongest: a paragraph break when either side had one (a marker on
  its own line between two paragraphs leaves exactly one `\\n\\n`), a single
  newline when either side had one, a single space when the marker only had
  horizontal whitespace around it, and nothing when it was flush against
  text. Content without markers is returned byte-identical.
  """

  @max_break_seconds 3.0
  @default_paragraph_break_seconds 1.2

  @marker_regex ~r/\{\s*pause\s*:\s*(\d+(?:\.\d+)?)\s*\}/i
  @malformed_marker_regex ~r/\{\s*pause[^}]*\}?/i
  @break_tag_regex ~r/<\s*break\b/i
  @paragraph_break_regex ~r/\s*\n\s*\n\s*/

  def max_break_seconds, do: @max_break_seconds

  def default_paragraph_break_seconds do
    Application.get_env(
      :lumen_viae,
      :tts_paragraph_break_seconds,
      @default_paragraph_break_seconds
    )
  end

  @doc """
  Strips `{pause:N}` markers from imported content.

  Returns `{:ok, clean_content, annotations}` where clean_content is safe to
  store and display, or `{:error, message}` when the content contains a
  literal `<break` tag or a pause marker that cannot be parsed.
  """
  def extract_pauses(content) when is_binary(content) do
    if Regex.match?(@break_tag_regex, content) do
      {:error,
       "content contains a literal <break tag; pauses are added at audio generation, " <>
         "use {pause:N} markers in the CSV instead"}
    else
      {clean, annotations} = strip_markers(content)

      case Regex.run(@malformed_marker_regex, clean) do
        nil ->
          {:ok, clean, annotations}

        [marker | _] ->
          {:error,
           "invalid pause marker #{inspect(marker)}; expected {pause:N} with N in seconds " <>
             "(decimals allowed, capped at #{trunc(@max_break_seconds)}s), e.g. {pause:1.5}"}
      end
    end
  end

  @doc """
  Builds the text sent to ElevenLabs from stored content and its persisted
  annotations. The result is never stored or displayed.

  Paragraph breaks become `<break time="Ns" />` tags using the configured
  default duration; annotations insert custom break tags at their offsets,
  absorbing any adjacent paragraph break so custom pauses replace the
  default rather than stack with it.

  Options:

    * `:paragraph_break_seconds` - override the configured default
  """
  def to_speech_text(content, annotations \\ [], opts \\ []) when is_binary(content) do
    default_seconds =
      Keyword.get(opts, :paragraph_break_seconds, default_paragraph_break_seconds())

    content
    |> split_at_annotations(sanitize_annotations(annotations, content))
    |> Enum.flat_map(fn
      {segment, nil} -> [String.trim(segment)]
      {segment, seconds} -> [String.trim(segment), break_tag(seconds)]
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> String.replace(@paragraph_break_regex, " #{break_tag(default_seconds)} ")
    |> String.trim()
  end

  ## Marker stripping

  defp strip_markers(content) do
    [first | rest] = Regex.split(@marker_regex, content, include_captures: true)
    do_strip(rest, first, [])
  end

  defp do_strip([], clean, annotations), do: {clean, Enum.reverse(annotations)}

  defp do_strip([marker, text | rest], clean, annotations) do
    left = String.trim_trailing(clean)
    right = String.trim_leading(text)
    junction = junction_whitespace(clean, left, text, right, rest)
    annotation = %{"offset" => String.length(left), "seconds" => marker_seconds(marker)}

    do_strip(rest, left <> junction <> right, [annotation | annotations])
  end

  # The whitespace that survives where a marker was removed (see moduledoc).
  defp junction_whitespace(clean, left, text, right, rest) do
    cond do
      left == "" ->
        ""

      right == "" and rest == [] ->
        ""

      true ->
        left_ws = String.replace_prefix(clean, left, "")
        right_ws = String.replace_suffix(text, right, "")

        case max(count_newlines(left_ws), count_newlines(right_ws)) do
          0 -> if left_ws == "" and right_ws == "", do: "", else: " "
          1 -> "\n"
          _ -> "\n\n"
        end
    end
  end

  defp count_newlines(whitespace) do
    whitespace |> String.graphemes() |> Enum.count(&(&1 == "\n"))
  end

  defp marker_seconds(marker) do
    [_, digits] = Regex.run(@marker_regex, marker)
    {seconds, _} = Float.parse(digits)
    clamp_seconds(seconds)
  end

  ## Break tag insertion

  # Annotations come either fresh from extract_pauses/1 or from the
  # tts_annotations jsonb column; anything malformed (hand-edited data,
  # offsets past the end after a content edit) is dropped or clamped rather
  # than crashing audio generation.
  defp sanitize_annotations(annotations, content) when is_list(annotations) do
    max_offset = String.length(content)

    annotations
    |> Enum.flat_map(fn
      %{"offset" => offset, "seconds" => seconds}
      when is_integer(offset) and offset >= 0 and is_number(seconds) ->
        [{min(offset, max_offset), seconds}]

      _other ->
        []
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp sanitize_annotations(_annotations, _content), do: []

  defp split_at_annotations(content, annotations) do
    {pieces, last, _base} =
      Enum.reduce(annotations, {[], content, 0}, fn {offset, seconds}, {pieces, rest, base} ->
        {left, right} = String.split_at(rest, offset - base)
        {[{left, seconds} | pieces], right, offset}
      end)

    Enum.reverse([{last, nil} | pieces])
  end

  defp break_tag(seconds) do
    ~s(<break time="#{seconds |> clamp_seconds() |> format_seconds()}s" />)
  end

  defp clamp_seconds(seconds), do: seconds |> max(0.0) |> min(@max_break_seconds)

  defp format_seconds(seconds) do
    truncated = trunc(seconds)
    if seconds == truncated, do: Integer.to_string(truncated), else: Float.to_string(seconds)
  end
end
