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

  @doc """
  Returns the canonical list of allowed labels, in admin display order.
  """
  def vocabulary, do: @vocabulary

  @doc """
  Maximum number of labels a single meditation set may carry.
  """
  def max_per_set, do: @max_per_set
end
