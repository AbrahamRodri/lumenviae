defmodule LumenViae.Rosary.Labels do
  @moduledoc """
  The controlled vocabulary for meditation set labels.

  Labels drive the iOS meditation picker: the app builds filter chips from
  the labels that appear in the catalog, and unfiltered browsing groups sets
  under each set's first label. The app compares labels as raw,
  case-sensitive strings, so every label written to the database must come
  from this canonical Title Case list.

  Order matters on a set: the first label is the set's primary group in the
  picker. Keep labels per set small (1-3); filtering in the app is AND, so a
  set should carry every label that genuinely describes it and nothing more.

  Style labels are mutually exclusive - a set carries at most one of:

    * "Contemplative" - imaginative, scene-based prayer in the Ignatian
      sense: the text places you inside the mystery and shows what was
      happening (Emmerich's visions, composition of place).
    * "Considerations" - discursive explanation in the classical manual
      sense: the text reasons about the mystery's meaning and doctrine
      (Sheen's essays, Liguori's "Consider how..." points).
  """

  @vocabulary [
    "Intentions",
    "Saints",
    "Scriptural",
    "Contemplative",
    "Considerations"
  ]

  @max_per_set 3

  # What the iOS app shows for a label, where it rewords the stored one. The
  # stored label is what filtering and grouping match; this only changes what
  # a reader sees, so the app never waits on a relabel in the database.
  # "Scriptural" reads as Gospel so that one thing on a mysteries' page is
  # called Scriptural (the Scriptural Rosary above the sets), and "Contemplative"
  # as Inside the Scene, what those meditations do, since the bare adjective
  # could not be told from Reflections beside it. The words are the app's
  # (MeditationLabel in MeditationSet.swift).
  @display_names %{
    "Considerations" => "Reflections",
    "Contemplative" => "Inside the Scene",
    "Scriptural" => "Gospel"
  }

  # The kinds of meditation, as the app's page "Kinds of Meditation"
  # explains them (RosaryMethodsView.swift). Each names a stored label, and
  # the voices in a description are examples, not an index of the library.
  @kinds [
    %{
      "label" => "Considerations",
      "icon" => "lv-rosary",
      "title" => "A reading and a prayer",
      "description" =>
        "A short reflection on the mystery, often with a prayer at the end. The words come from preachers and the Church's great teachers. Read it once, then keep it in mind through the ten Hail Marys.\n\nSt. Alphonsus Liguori · Venerable Fulton J. Sheen · St. John Henry Newman · St. Thomas Aquinas"
    },
    %{
      "label" => "Contemplative",
      "icon" => "ch-candle",
      "title" => "Inside the scene",
      "description" =>
        "Longer passages that place you within the mystery: what was seen, heard, and felt there. Read slowly. You do not need to finish the page before the ten Hail Marys end.\n\nBlessed Anne Catherine Emmerich · Venerable Mary of Agreda · St. Ignatius of Loyola · Fr. Frederick William Faber"
    },
    %{
      "label" => "Saints",
      "icon" => "lv-saint",
      "title" => "In a saint's own words",
      "description" =>
        "Meditations written by saints. They also appear under their other kind.\n\nSt. Alphonsus's, for example, are under both Saints and Reflections."
    },
    %{
      "label" => "Scriptural",
      "icon" => "ch-bible",
      "title" => "The Gospel first",
      "description" =>
        "The Scripture passage for the mystery, then a few lines of meditation on it.\n\nThe Seven Sorrows are set this way, because the Gospel tells the whole scene. For a verse on every bead, open any of the mysteries and choose The Scriptural Rosary, above the meditations."
    }
  ]

  @doc """
  Returns the canonical list of allowed labels, in admin display order.
  """
  def vocabulary, do: @vocabulary

  @doc """
  Maximum number of labels a single meditation set may carry.
  """
  def max_per_set, do: @max_per_set

  @doc """
  What a reader sees for a stored label: the app's wording where it has
  one, the label itself otherwise.
  """
  @spec display_name(String.t()) :: String.t()
  def display_name(label), do: Map.get(@display_names, label, label)

  @doc """
  The labels the app words differently, stored label to what a reader
  sees.
  """
  @spec display_names() :: %{String.t() => String.t()}
  def display_names, do: @display_names

  @doc """
  The kinds of meditation, each `%{"label", "icon", "title",
  "description"}`, in the order the app explains them.
  """
  @spec kinds() :: [map]
  def kinds, do: @kinds
end
