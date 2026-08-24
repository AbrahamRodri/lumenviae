defmodule LumenViae.Office.Parser do
  @moduledoc """
  Turns the HTML a Divinum Officium instance answers with into data.

  The engine renders an hour as one table: a row per section of the
  office, a Latin cell on the left and the requested translation on the
  right. Each cell opens with a large red section title ("Incipit",
  "Psalmi", "Oratio"), sometimes followed by a small rubric note in
  braces, then the text itself with a `<br/>` per line. The Latin cell of
  every section row carries an anchor id of the hour name plus a counter
  ("Laudes1", "Laudes2", ...), which is what identifies a section row
  amid the form and menu tables on the same page.

  Everything here is structural - tag shapes and positions, not colors or
  fonts - so cosmetic upstream changes do not break it. What would break
  it is the engine renaming its anchors or reshaping its rows, which is
  why `parse_hour/2` answers `{:error, :unparseable}` the moment a page
  yields no sections rather than returning something half-read.
  """

  @doc """
  Parses one hour's page.

      {:ok, %{celebration: %{title: ..., rank: ...} | nil,
              tempora: ... | nil,
              sections: [%{latin: cell, vernacular: cell}]}}

  where a cell is `%{title: ..., note: ..., lines: [...]}`.

  The anchor prefix is read off the page's own `<h2 id="...top">`
  heading rather than assumed from the hour that was asked for, because
  the two differ: asking for "Vesperae" answers a page anchored
  "Vespera1", "Vespera2", ...
  """
  def parse_hour(html) when is_binary(html) do
    with {:ok, doc} <- parse_document(html),
         {:ok, anchor_prefix} <- anchor_prefix(doc) do
      case sections(doc, anchor_prefix) do
        [] ->
          {:error, :unparseable}

        sections ->
          {celebration, tempora} = day_header(doc)
          {:ok, %{celebration: celebration, tempora: tempora, sections: sections}}
      end
    end
  end

  @doc """
  Parses one month of the engine's calendar into a list of days:

      {:ok, [%{date: ~D[...], celebration: %{title: ..., rank: ...} | nil,
               detail: %{label: ..., text: ...} | nil,
               note: ... | nil, letter: ... | nil}]}

  `detail` is the calendar's second column verbatim: usually the season
  ("Tempora"), on other days a commemoration line. The year and month are
  taken on trust from the caller, since the page itself only shows day
  numbers.
  """
  def parse_kalendar(html, year, month) when is_binary(html) do
    with {:ok, doc} <- parse_document(html) do
      days =
        doc
        |> Floki.find("tr")
        |> Enum.map(&direct_tds/1)
        |> Enum.filter(&(length(&1) == 5))
        |> Enum.flat_map(&kalendar_day(&1, year, month))

      if days == [], do: {:error, :unparseable}, else: {:ok, days}
    end
  end

  defp parse_document(html) do
    case Floki.parse_document(html) do
      {:ok, doc} -> {:ok, doc}
      {:error, _reason} -> {:error, :unparseable}
    end
  end

  # -- The day header ------------------------------------------------------
  #
  # The first <p> with a direct <font> child is the day's masthead: the
  # celebration in that font (title and rank joined by "~"), and the
  # season in an <i> underneath, prefixed by a "Tempora:" label.

  defp day_header(doc) do
    header_p =
      doc
      |> Floki.find("p")
      |> Enum.find(fn {_p, _attrs, children} ->
        Enum.any?(children, &match?({"font", _, _}, &1))
      end)

    case header_p do
      nil ->
        {nil, nil}

      {_p, _attrs, children} ->
        celebration =
          children
          |> Enum.find(&match?({"font", _, _}, &1))
          |> text_of()
          |> split_celebration()

        tempora =
          header_p
          |> Floki.find("i")
          |> text_of()
          |> strip_label("Tempora:")
          |> presence()

        {celebration, tempora}
    end
  end

  defp split_celebration(text) do
    case text |> normalize() |> String.split("~", parts: 2) do
      [""] -> nil
      [title] -> %{title: String.trim(title), rank: nil}
      [title, rank] -> %{title: String.trim(title), rank: presence(rank)}
    end
  end

  # -- Section rows --------------------------------------------------------

  # <H2 ID='Vesperatop'>Ad Vesperas</H2> names the hour as the anchors
  # spell it; a page without one is not an office.
  defp anchor_prefix(doc) do
    doc
    |> Floki.find("h2")
    |> Enum.find_value({:error, :unparseable}, fn {"h2", attrs, _children} ->
      with id when is_binary(id) <- attr(attrs, "id"),
           prefix when prefix != "" <- String.trim_trailing(id, "top") do
        if prefix == id, do: nil, else: {:ok, prefix}
      else
        _not_an_hour_anchor -> nil
      end
    end)
  end

  # The office is the one table whose cells carry the hour anchors. Every
  # row of it is content, including the occasional anchor-less rubric row
  # ("Preces Dominicales {omittitur}"). Two cells per row normally; one
  # full-width cell when Latin itself is the requested translation, since
  # the engine then drops the second column rather than printing the same
  # text twice.
  defp sections(doc, anchor_prefix) do
    anchor = ~r/^#{Regex.escape(anchor_prefix)}\d+$/

    doc
    |> Floki.find("table")
    |> Enum.find(fn table ->
      table |> Floki.find("td") |> Enum.any?(&section_anchor?(&1, anchor))
    end)
    |> case do
      nil ->
        []

      table ->
        table
        |> Floki.find("tr")
        |> Enum.map(&direct_tds/1)
        |> Enum.filter(&(length(&1) in [1, 2]))
        |> Enum.map(fn
          [latin, vernacular] -> %{latin: cell(latin), vernacular: cell(vernacular)}
          [latin] -> %{latin: cell(latin), vernacular: nil}
        end)
    end
  end

  defp section_anchor?({"td", attrs, _children}, anchor) do
    case attr(attrs, "id") do
      nil -> false
      id -> Regex.match?(anchor, id)
    end
  end

  # One cell: drop the navigation <div>, split the rest into lines at each
  # <br/>, and read the title (and optional brace note) off the first line.
  defp cell({"td", _attrs, children}) do
    chunks =
      children
      |> Enum.reject(&match?({"div", _, _}, &1))
      |> chunk_by_br()

    case chunks do
      [first | rest] ->
        case header_of(first) do
          {title, note} ->
            %{title: title, note: note, lines: lines_of(rest)}

          :not_a_header ->
            %{title: nil, note: nil, lines: lines_of(chunks)}
        end

      [] ->
        %{title: nil, note: nil, lines: []}
    end
  end

  # Only the enlarged font opens a section; the psalm rows open with a
  # small red "Ant." font and must stay ordinary lines.
  defp header_of(nodes) do
    case Enum.split_while(nodes, &(not title_font?(&1))) do
      {_leading, [title_font | after_title]} ->
        {presence(text_of(title_font)), presence(text_of(after_title))}

      {_all, []} ->
        :not_a_header
    end
  end

  defp title_font?({"font", attrs, _children}), do: attr(attrs, "size") == "+1"
  defp title_font?(_other), do: false

  defp lines_of(chunks) do
    chunks
    |> Enum.map(&text_of/1)
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp chunk_by_br(nodes) do
    nodes
    |> Enum.chunk_while(
      [],
      fn
        {"br", _, _}, acc -> {:cont, Enum.reverse(acc), []}
        node, acc -> {:cont, [node | acc]}
      end,
      fn acc -> {:cont, Enum.reverse(acc), []} end
    )
  end

  # -- Calendar rows -------------------------------------------------------

  defp kalendar_day([day_td, second_td, third_td, note_td, letter_td], year, month) do
    with {day, ""} <- day_td |> text_of() |> normalize() |> Integer.parse(),
         {:ok, date} <- Date.new(year, month, day) do
      # The celebration is the bold cell. Weekdays put it in the third
      # column with the season in the second; Sundays put it in the
      # second and leave the third empty.
      {celebration_td, detail_td} =
        if Floki.find(second_td, "b") == [],
          do: {third_td, second_td},
          else: {second_td, third_td}

      [
        %{
          date: date,
          celebration: celebration_of(celebration_td),
          detail: detail_of(detail_td),
          note: note_td |> text_of() |> presence(),
          letter: letter_td |> text_of() |> presence()
        }
      ]
    else
      _not_a_day_row -> []
    end
  end

  # <td><b>title</b><font>rank</font></td> - the rank font is the only
  # font that is a direct child of the cell.
  defp celebration_of({"td", _attrs, children}) do
    title =
      children
      |> Enum.filter(&match?({"b", _, _}, &1))
      |> text_of()
      |> presence()

    rank =
      children
      |> Enum.filter(&match?({"font", _, _}, &1))
      |> text_of()
      |> presence()

    if title, do: %{title: title, rank: rank}, else: nil
  end

  # <td><font>label:</font><i>text</i></td>
  defp detail_of({"td", _attrs, children} = td) do
    label =
      children
      |> Enum.filter(&match?({"font", _, _}, &1))
      |> text_of()
      |> normalize()
      |> String.trim_trailing(":")
      |> presence()

    text = td |> Floki.find("i") |> text_of() |> presence()

    if label || text, do: %{label: label, text: text}, else: nil
  end

  # -- Node plumbing -------------------------------------------------------

  defp direct_tds({"tr", _attrs, children}) do
    for {"td", _, _} = td <- children, do: td
  end

  defp direct_tds(_other), do: []

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn {key, value} ->
      if String.downcase(key) == name, do: value
    end)
  end

  defp text_of(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &text_of/1)
  defp text_of(text) when is_binary(text), do: text
  defp text_of({:comment, _}), do: ""
  defp text_of({_tag, _attrs, children}), do: text_of(children)
  defp text_of(nil), do: ""
  defp text_of(_other), do: ""

  # The `u` flag makes \s match the non-breaking and en spaces the engine
  # uses as layout glue.
  defp normalize(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp strip_label(text, label) do
    text
    |> normalize()
    |> String.replace_prefix(label, "")
    |> String.trim()
  end

  defp presence(nil), do: nil

  defp presence(text) when is_binary(text) do
    case normalize(text) do
      "" -> nil
      normalized -> normalized
    end
  end
end
