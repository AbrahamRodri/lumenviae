defmodule LumenViae.Constants do
  @moduledoc """
  Application-wide constants.
  """

  @mystery_categories [
    {"Joyful Mysteries", "joyful"},
    {"Sorrowful Mysteries", "sorrowful"},
    {"Glorious Mysteries", "glorious"},
    {"Seven Sorrows of Mary", "seven_sorrows"}
  ]

  def mystery_categories, do: @mystery_categories

  def mystery_category_options do
    @mystery_categories
  end

  def mystery_category_label(category) do
    case category do
      "joyful" -> "Joyful Mysteries"
      "sorrowful" -> "Sorrowful Mysteries"
      "glorious" -> "Glorious Mysteries"
      "seven_sorrows" -> "Seven Sorrows of Mary"
      _ -> category
    end
  end
end
