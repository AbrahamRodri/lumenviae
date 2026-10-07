defmodule LumenViaeWeb.PageMeta do
  @moduledoc """
  What a public page tells search engines and link previews about itself:
  its title, description, canonical address, preview image and breadcrumb.

  A value module in the sense of `LumenViae.Rosary.Categories`: no state, no
  queries. A public LiveView calls `put/3` from `mount/3`, which assigns
  `:page_title`, `:meta_description` and `:meta`; the root layout reads them
  through `LumenViaeWeb.Components.MetaTags`, so the tags are in the first,
  server-rendered response, which is the one a crawler reads.

      socket
      |> PageMeta.put("/mysteries/joyful",
        title: "The Joyful Mysteries",
        description: "...",
        image: PageMeta.plate_image("joyful_1"),
        trail: [{"The Joyful Mysteries", "/mysteries/joyful"}]
      )

  Paths are the site's own, with no query string: a canonical address names
  the page, not the filter or the bead it was opened on.
  """

  alias LumenViae.Rosary.Categories
  alias LumenViaeWeb.Components.WoodcutPlate

  @site "https://www.lumenviae.org"
  @site_name "Lumen Viae"

  # The description a search result shows is cut at about 160 characters.
  @max_description 160

  # What link previews show for a page with no picture of its own: the Our
  # Lady of Sorrows banner, a JPEG because not every preview crawler reads
  # WebP.
  @default_image %{
    path: "/images/pngs/our-lady-of-sorrows-horizontal.jpg",
    width: 1200,
    height: 410,
    alt: "Our Lady of Sorrows"
  }

  # The woodcut a category's page and its card in a link preview show: the
  # same prints the category page's header shows until its painting is
  # published.
  @category_plates %{
    "joyful" => "joyful_1",
    "sorrowful" => "sorrowful_5",
    "glorious" => "glorious_1",
    "luminous" => "luminous_1",
    "seven_sorrows" => "seven_sorrows_6"
  }

  @doc "The site's address, with no trailing slash."
  def site_url, do: @site

  @doc "The site's name."
  def site_name, do: @site_name

  @doc "The longest description a page may carry, in characters."
  def max_description, do: @max_description

  @doc "The absolute address of a path on the site."
  def absolute_url(path), do: @site <> path

  @doc """
  Assigns a page's metadata: `:page_title`, `:meta_description` and `:meta`.

  `path` is the page's canonical path. Options:

    * `:title` and `:description` (required). The description is cut to
      `max_description/0` characters at a word.
    * `:image` - `plate_image/1`'s result, or `nil` for the default banner.
    * `:trail` - the page's breadcrumb below Home, as `{name, path}` pairs
      ending with the page itself; empty on the home page and on pages with
      no parent.
    * `:json_ld` - extra structured data, as maps, rendered after the
      breadcrumb's.
  """
  def put(socket, path, opts) do
    meta = build(path, opts)

    socket
    |> Phoenix.Component.assign(:page_title, meta.title)
    |> Phoenix.Component.assign(:meta_description, meta.description)
    |> Phoenix.Component.assign(:meta, meta)
  end

  @doc "Builds the metadata `put/3` assigns, without a socket."
  def build(path, opts) do
    title = Keyword.fetch!(opts, :title)
    description = opts |> Keyword.fetch!(:description) |> clamp()
    image = opts[:image] || default_image()
    trail = Keyword.get(opts, :trail, [])

    %{
      title: title,
      description: description,
      path: path,
      url: absolute_url(path),
      image: image,
      type: "website",
      card: card(image),
      json_ld: breadcrumb(trail) ++ Keyword.get(opts, :json_ld, [])
    }
  end

  @doc """
  The preview image for a mystery's woodcut, by mystery key (`"joyful_1"`):
  its JPEG as an absolute address, with its size and what it shows. Nil for a
  key with no plate.
  """
  def plate_image(key) do
    case WoodcutPlate.plate(key) do
      nil ->
        nil

      plate ->
        %{
          url: absolute_url(plate.src),
          width: plate.width,
          height: plate.height,
          alt: plate.alt
        }
    end
  end

  @doc "The preview image for a category's page: the woodcut its header shows."
  def category_image(category), do: plate_image(Map.get(@category_plates, category))

  @doc "The banner link previews show for the home page and for any page with no woodcut."
  def default_image do
    %{
      url: absolute_url(@default_image.path),
      width: @default_image.width,
      height: @default_image.height,
      alt: @default_image.alt
    }
  end

  @doc """
  The Twitter card for an image: the large card for a wide picture, the
  small one for a tall one, which the large card would crop to a strip.
  """
  def card(%{width: width, height: height}) when height > width, do: "summary"
  def card(_image), do: "summary_large_image"

  @doc """
  A description cut to `max_description/0` characters. A longer one is cut
  at the last space that fits and ends in "..."; a shorter one is returned
  as it is.
  """
  def clamp(text) when is_binary(text) do
    text = String.trim(text)

    if String.length(text) <= @max_description do
      text
    else
      text
      |> String.slice(0, @max_description - 3)
      |> String.replace(~r/\s+\S*$/, "")
      |> String.trim_trailing(",;:.")
      |> Kernel.<>("...")
    end
  end

  @doc """
  `WebSite` structured data for the home page. It names the site and says
  what it is for, and claims nothing else: no search action, since the site
  has no search.
  """
  def website(description) do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => @site_name,
      "url" => @site <> "/",
      "description" => description,
      "inLanguage" => "en"
    }
  end

  @doc """
  A `BreadcrumbList` from Home through `trail`, a list of `{name, path}`
  pairs. Empty when there is no trail.
  """
  def breadcrumb([]), do: []

  def breadcrumb(trail) do
    items =
      [{"Home", "/"} | trail]
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, path}, position} ->
        %{
          "@type" => "ListItem",
          "position" => position,
          "name" => name,
          "item" => absolute_url(path)
        }
      end)

    [
      %{
        "@context" => "https://schema.org",
        "@type" => "BreadcrumbList",
        "itemListElement" => items
      }
    ]
  end

  @doc "A category's name as a title: \"The Joyful Mysteries\"."
  def category_title("seven_sorrows"), do: "The Seven Sorrows of Mary"
  def category_title(category), do: "The #{Categories.name(category)} Mysteries"

  ## Prayer pages

  @doc """
  The options for `put/3` on a set's prayer page: the set's name, its author
  and the mysteries it prays.

  `mystery_names` are the names of the set's decades in prayer order and
  `first_key` is the first decade's mystery key (`"joyful_3"`), whose woodcut
  is the preview image.
  """
  def pray_set(set, mystery_names, first_key) do
    category = set.category
    author = set_author(set)

    [
      title: set_title(set.name, category),
      description: set_description(set.name, author, category, mystery_names),
      image: plate_image(first_key) || category_image(category),
      trail: [
        {category_title(category), "/mysteries/#{category}"},
        {set.name, "/meditation-sets/#{set.id}/pray"}
      ]
    ]
  end

  @doc """
  The options for `put/3` on a category's prayer page, which prays it
  without a set. `mystery_names` are the category's mysteries in order.
  """
  def pray_category(category, mystery_names) do
    devotion = Categories.devotion_title(category)

    [
      title: "Pray the #{devotion}",
      description:
        first_that_fits([
          "Pray the #{devotion} of the Holy Rosary, aloud or on your beads, with the Scripture for each: #{join_names(mystery_names)}.",
          "Pray the #{count_word(category)} #{devotion} of the Holy Rosary decade by decade, aloud or on your beads, with the Scripture for each mystery.",
          "Pray the #{devotion} of the Holy Rosary, aloud or on your beads."
        ]),
      image: plate_image("#{category}_1") || category_image(category),
      trail: [
        {category_title(category), "/mysteries/#{category}"},
        {"Pray the #{devotion}", "/mysteries/#{category}/pray"}
      ]
    ]
  end

  @doc """
  The author a set is shown with: its own byline, else its linked author's
  name, else the one its meditations agree on. Nil when none is known.
  """
  def set_author(set) do
    profile_name =
      case Map.get(set, :author_profile) do
        %{name: name} -> name
        _none -> nil
      end

    blank_to_nil(set.author) || blank_to_nil(profile_name) ||
      blank_to_nil(Map.get(set, :derived_author))
  end

  # "Venerable Fulton J. Sheen: Pray the Joyful Mysteries". A name that
  # already says which mysteries it is for stands alone.
  defp set_title(name, category) do
    if String.contains?(String.downcase(name), String.downcase(Categories.name(category))),
      do: name,
      else: "#{name}: Pray the #{Categories.devotion_title(category)}"
  end

  defp set_description(name, author, category, mystery_names) do
    lead =
      cond do
        is_nil(author) -> "Pray the Rosary with #{name}"
        author == name -> "Pray the Rosary with meditations by #{author}"
        true -> "Pray the Rosary with #{name}, meditations by #{author}"
      end

    devotion = Categories.devotion_title(category)

    first_that_fits([
      "#{lead}, on #{join_names(mystery_names)}.",
      "#{lead}, on the #{devotion}.",
      "#{lead}."
    ])
  end

  # The first sentence that fits a description, or the last one cut to fit.
  defp first_that_fits(candidates) do
    Enum.find(candidates, &(String.length(&1) <= @max_description)) ||
      candidates |> List.last() |> clamp()
  end

  # "the Annunciation, the Visitation and the Nativity"; a name that is not
  # "The ..." ("Mary Meets Jesus Carrying the Cross") is left as it is.
  defp join_names(names) do
    names
    |> Enum.map(fn
      "The " <> rest -> "the " <> rest
      name -> name
    end)
    |> join_list()
  end

  defp join_list([]), do: ""
  defp join_list([one]), do: one
  defp join_list(list), do: Enum.join(Enum.drop(list, -1), ", ") <> " and " <> List.last(list)

  defp count_word(category),
    do: if(Categories.mystery_count(category) == 7, do: "seven", else: "five")

  defp blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp blank_to_nil(_value), do: nil
end
