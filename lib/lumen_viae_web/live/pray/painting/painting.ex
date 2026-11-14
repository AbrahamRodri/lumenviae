defmodule LumenViaeWeb.Live.Pray.Painting do
  @moduledoc """
  The mystery's painting above the words, as the app's prayer screen shows
  it. On a phone it fills the width at the top of the page and fades into
  the night below; from 1024 px it stands on the left, the height of the
  window, fading into the night on its right edge, with the prayer beside
  it.

  The same painting stays through a mystery's steps. The opening prayers
  show the first mystery's, and the closing prayers the Crucifixion, as
  the app does. It is decorative (`alt=""`): the mystery is named in the
  page's heading. The reader's "Images: Hide" choice hides it, as it hides
  the decade's plate.
  """
  use LumenViaeWeb, :html

  alias LumenViaeWeb.Components.MysteryPainting

  attr :decades, :list, required: true
  attr :page, :integer, required: true
  attr :category, :string, required: true

  def hero(assigns) do
    source = source(assigns.decades, assigns.page, assigns.category)
    assigns = assigns |> assign(:source, source) |> assign(:shown, painted?(source))

    ~H"""
    <div :if={@shown} class="prayer-plate prayer-hero" aria-hidden="true">
      <MysteryPainting.picture
        key={@source.key}
        record={@source.record}
        alt=""
        sizes="(min-width: 1024px) 44vw, 100vw"
        loading="eager"
        class="prayer-hero-image"
      />
    </div>
    """
  end

  # Page 0 is the opening prayers, 1 to n the decades, and the page after
  # the last decade the closing prayers.
  defp source([first | _], 0, _category), do: %{key: first.key, record: first.mystery}

  defp source(decades, page, category) when page > length(decades),
    do: %{key: crucifixion(category), record: nil}

  defp source(decades, page, _category) do
    decade = Enum.at(decades, page - 1)
    %{key: decade.key, record: decade.mystery}
  end

  # Only a mystery with a painting gets the space for one.
  defp painted?(%{key: key, record: record}), do: MysteryPainting.painted?(key, record)

  defp crucifixion("seven_sorrows"), do: "seven_sorrows_5"
  defp crucifixion(_category), do: "sorrowful_5"
end
