defmodule LumenViae.Scripture do
  @moduledoc """
  Scripture passages for the mysteries of the Rosary.
  """

  @scriptures %{
    annunciation: %{
      reference: "Luke 1:26–38 - Douay-Rheims",
      verses: [
        {"1:26", "And in the sixth month, the angel Gabriel was sent from God into a city of Galilee, called Nazareth,"},
        {"1:27", "To a virgin espoused to a man whose name was Joseph, of the house of David; and the virgin's name was Mary."},
        {"1:28", "And the angel being come in, said unto her: Hail, full of grace, the Lord is with thee: blessed art thou among women."},
        {"1:29", "Who having heard, was troubled at his saying, and thought with herself what manner of salutation this should be."},
        {"1:30", "And the angel said to her: Fear not, Mary, for thou hast found grace with God."},
        {"1:31", "Behold thou shalt conceive in thy womb, and shalt bring forth a son; and thou shalt call his name Jesus."},
        {"1:32", "He shall be great, and shall be called the Son of the most High; and the Lord God shall give unto him the throne of David his father; and he shall reign in the house of Jacob for ever."},
        {"1:33", "And of his kingdom there shall be no end."},
        {"1:34", "And Mary said to the angel: How shall this be done, because I know not man?"},
        {"1:35", "And the angel answering, said to her: The Holy Ghost shall come upon thee, and the power of the most High shall overshadow thee. And therefore also the Holy which shall be born of thee shall be called the Son of God."},
        {"1:36", "And behold thy cousin Elizabeth, she also hath conceived a son in her old age; and this is the sixth month with her that is called barren:"},
        {"1:37", "Because no word shall be impossible with God."},
        {"1:38", "And Mary said: Behold the handmaid of the Lord; be it done to me according to thy word. And the angel departed from her."}
      ]
    }
    # Add more scripture passages here as needed
  }

  @doc """
  Gets a scripture passage by key.
  """
  def get(key) when is_atom(key) do
    Map.get(@scriptures, key)
  end

  @doc """
  Gets all available scripture keys.
  """
  def keys do
    Map.keys(@scriptures)
  end

  @doc """
  Formats verses as a single paragraph with inline verse numbers.
  """
  def format_verses(verses) when is_list(verses) do
    verses
    |> Enum.map(fn {num, text} -> {num, text} end)
    |> Enum.reduce([], fn {num, text}, acc ->
      acc ++ [{:safe, ~s(<span class="text-gold font-semibold">#{num}</span> #{text})}]
    end)
  end
end
