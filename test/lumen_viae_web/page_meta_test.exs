defmodule LumenViaeWeb.PageMetaTest do
  @moduledoc """
  What every public page says about itself in its `<head>`, in the first
  response a crawler or a link preview reads: a title and description of its
  own, a canonical address with no query string, a preview image with its
  size, and structured data that claims no more than the page is.

  `async: false` because it seeds the real mysteries, which have fixed
  (category, order) keys.
  """
  use LumenViaeWeb.ConnCase, async: false

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Categories
  alias LumenViae.Test.Mysteries
  alias LumenViaeWeb.Components.WoodcutPlate
  alias LumenViaeWeb.PageMeta

  @site "https://www.lumenviae.org"

  setup do
    mysteries = Mysteries.seed_app_mysteries()
    %{mysteries: mysteries}
  end

  # A visible set praying the Joyful Mysteries from the third on, with the
  # real mysteries, so its first mystery has a woodcut of its own.
  defp joyful_set(mysteries, attrs \\ %{}) do
    {:ok, set} =
      Rosary.create_meditation_set(
        Map.merge(%{name: "A Set For Meta", category: "joyful"}, attrs),
        actor: admin()
      )

    for order <- [3, 4] do
      mystery = Enum.find(mysteries, &(&1.category == "joyful" and &1.order == order))

      {:ok, meditation} =
        Rosary.create_meditation(
          %{content: "A meditation.", author: "St. Bernard of Clairvaux", mystery_id: mystery.id},
          actor: admin()
        )

      {:ok, _} =
        Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end

    set
  end

  defp page(conn, path) do
    conn |> get(path) |> html_response(200) |> Floki.parse_document!()
  end

  defp content(doc, selector) do
    case doc |> Floki.find(selector) |> Floki.attribute("content") do
      [value] -> value
      other -> flunk("expected one #{selector}, found #{inspect(other)}")
    end
  end

  defp title(doc), do: doc |> Floki.find("head title") |> Floki.text()

  defp canonical(doc) do
    [href] = doc |> Floki.find(~s(link[rel="canonical"])) |> Floki.attribute("href")
    href
  end

  defp json_ld(doc) do
    doc
    |> Floki.find(~s(script[type="application/ld+json"]))
    |> Enum.map(&(&1 |> Floki.text(js: true) |> Jason.decode!()))
  end

  defp types(doc), do: doc |> json_ld() |> Enum.map(& &1["@type"])

  defp breadcrumb_names(doc) do
    [list] = Enum.filter(json_ld(doc), &(&1["@type"] == "BreadcrumbList"))
    Enum.map(list["itemListElement"], & &1["name"])
  end

  describe "every public page" do
    test "has a title and description of its own, a canonical link and a preview", %{
      conn: conn,
      mysteries: mysteries
    } do
      set = joyful_set(mysteries)

      paths =
        ["/", "/mysteries", "/privacy-policy", "/app", "/meditation-sets/#{set.id}/pray"] ++
          Enum.map(Categories.slugs(), &"/mysteries/#{&1}") ++
          Enum.map(Categories.slugs(), &"/mysteries/#{&1}/pray")

      pages =
        for path <- paths do
          doc = page(conn, path)
          description = content(doc, ~s(meta[name="description"]))

          assert String.length(description) in 40..160,
                 "#{path}: description is #{String.length(description)} characters"

          assert content(doc, ~s(meta[property="og:description"])) == description
          assert content(doc, ~s(meta[name="twitter:description"])) == description

          assert title(doc) =~ " | Lumen Viae"
          assert content(doc, ~s(meta[property="og:title"])) != ""

          assert content(doc, ~s(meta[property="og:title"])) ==
                   content(doc, ~s(meta[name="twitter:title"]))

          assert content(doc, ~s(meta[property="og:type"])) == "website"
          assert content(doc, ~s(meta[property="og:site_name"])) == "Lumen Viae"

          assert canonical(doc) == @site <> path
          assert content(doc, ~s(meta[property="og:url"])) == @site <> path

          image = content(doc, ~s(meta[property="og:image"]))
          assert String.starts_with?(image, @site <> "/images/")
          assert content(doc, ~s(meta[name="twitter:image"])) == image
          assert String.to_integer(content(doc, ~s(meta[property="og:image:width"]))) > 0
          assert String.to_integer(content(doc, ~s(meta[property="og:image:height"]))) > 0
          assert content(doc, ~s(meta[property="og:image:alt"])) != ""

          {path, title(doc), description}
        end

      titles = Enum.map(pages, &elem(&1, 1))
      descriptions = Enum.map(pages, &elem(&1, 2))

      assert titles == Enum.uniq(titles)
      assert descriptions == Enum.uniq(descriptions)
    end

    test "carries no rating, review or search action in its structured data", %{
      conn: conn,
      mysteries: mysteries
    } do
      set = joyful_set(mysteries)

      for path <- [
            "/",
            "/mysteries/joyful",
            "/mysteries/joyful/pray",
            "/meditation-sets/#{set.id}/pray"
          ] do
        html = conn |> get(path) |> html_response(200)

        for forbidden <- ["aggregateRating", "Review", "Rating", "SearchAction"] do
          json = html |> Floki.parse_document!() |> json_ld() |> Jason.encode!()
          refute json =~ forbidden, "#{path} claims #{forbidden}"
        end
      end
    end
  end

  describe "the home page" do
    test "keeps the banner as its preview, and is a WebSite", %{conn: conn} do
      doc = page(conn, "/")

      assert content(doc, ~s(meta[property="og:image"])) ==
               @site <> "/images/pngs/our-lady-of-sorrows-horizontal.jpg"

      assert content(doc, ~s(meta[property="og:image:width"])) == "1200"
      assert content(doc, ~s(meta[property="og:image:height"])) == "410"
      assert content(doc, ~s(meta[name="twitter:card"])) == "summary_large_image"

      assert types(doc) == ["WebSite"]
      [site] = json_ld(doc)
      assert site["name"] == "Lumen Viae"
      assert site["url"] == @site <> "/"
    end
  end

  describe "the Scripture and privacy pages" do
    test "say what they are", %{conn: conn} do
      scripture = page(conn, "/mysteries")
      assert title(scripture) =~ "Scripture"
      assert content(scripture, ~s(meta[name="description"])) =~ "Douay-Rheims"
      assert types(scripture) == []

      privacy = page(conn, "/privacy-policy")
      assert title(privacy) =~ "Privacy Policy"
      assert content(privacy, ~s(meta[name="description"])) =~ "information"
    end
  end

  describe "a category page" do
    for category <- Categories.slugs() do
      test "#{category} names itself and previews with its woodcut", %{conn: conn} do
        category = unquote(category)
        doc = page(conn, "/mysteries/#{category}")

        assert title(doc) =~ PageMeta.category_title(category)
        assert content(doc, ~s(meta[name="description"])) =~ "Pray"

        image = PageMeta.category_image(category)
        assert content(doc, ~s(meta[property="og:image"])) == image.url
        assert content(doc, ~s(meta[property="og:image:width"])) == to_string(image.width)
        assert content(doc, ~s(meta[property="og:image:height"])) == to_string(image.height)
        assert String.ends_with?(image.url, ".jpg")

        assert breadcrumb_names(doc) == ["Home", PageMeta.category_title(category)]
      end
    end

    test "a tall woodcut is a summary card, as the large card would crop it", %{conn: conn} do
      doc = page(conn, "/mysteries/joyful")
      assert content(doc, ~s(meta[name="twitter:card"])) == "summary"
    end

    test "strips the filter's query string from the canonical link", %{conn: conn} do
      doc = page(conn, "/mysteries/joyful?kind=meditation&narrated=true")

      assert canonical(doc) == @site <> "/mysteries/joyful"
      assert content(doc, ~s(meta[property="og:url"])) == @site <> "/mysteries/joyful"
    end
  end

  describe "a set's prayer page" do
    test "names the set, its author and its mysteries, and previews its first mystery", %{
      conn: conn,
      mysteries: mysteries
    } do
      set = joyful_set(mysteries)
      doc = page(conn, "/meditation-sets/#{set.id}/pray")

      assert title(doc) =~ "A Set For Meta"
      assert title(doc) =~ "Joyful Mysteries"

      description = content(doc, ~s(meta[name="description"]))
      assert description =~ "A Set For Meta"
      assert description =~ "St. Bernard of Clairvaux"
      assert description =~ "the Nativity"
      assert description =~ "the Presentation"
      refute description =~ "the Annunciation"

      image = WoodcutPlate.plate("joyful_3")
      assert content(doc, ~s(meta[property="og:image"])) == @site <> image.src
      assert content(doc, ~s(meta[property="og:image:width"])) == to_string(image.width)
      assert content(doc, ~s(meta[property="og:image:height"])) == to_string(image.height)
      assert content(doc, ~s(meta[property="og:image:alt"])) == image.alt

      assert breadcrumb_names(doc) == ["Home", "The Joyful Mysteries", "A Set For Meta"]
    end

    test "strips the place in the Rosary from the canonical link", %{
      conn: conn,
      mysteries: mysteries
    } do
      set = joyful_set(mysteries)
      doc = page(conn, "/meditation-sets/#{set.id}/pray?mystery=1&count=screen&voice=x")

      assert canonical(doc) == @site <> "/meditation-sets/#{set.id}/pray"
    end

    test "does not say 'by' the set's own name twice when the set is named for its author", %{
      conn: conn,
      mysteries: mysteries
    } do
      set =
        joyful_set(mysteries, %{
          name: "Venerable Fulton J. Sheen",
          author: "Venerable Fulton J. Sheen"
        })

      doc = page(conn, "/meditation-sets/#{set.id}/pray")

      description = content(doc, ~s(meta[name="description"]))
      assert description =~ "meditations by Venerable Fulton J. Sheen"
      refute description =~ "Sheen, meditations by"
    end

    test "cuts a long description to fit, and escapes a hostile name", %{
      conn: conn,
      mysteries: mysteries
    } do
      name = "</script><script>alert(1)</script> " <> String.duplicate("Long Name ", 20)
      set = joyful_set(mysteries, %{name: name})

      html = conn |> get("/meditation-sets/#{set.id}/pray") |> html_response(200)
      doc = Floki.parse_document!(html)

      assert String.length(content(doc, ~s(meta[name="description"]))) <=
               PageMeta.max_description()

      # The name reaches the structured data, and cannot close its script tag.
      refute html =~ "</script><script>alert(1)"
      assert Enum.any?(breadcrumb_names(doc), &(&1 == name))
    end
  end

  describe "a category's prayer page, without a set" do
    test "names the devotion and previews its first mystery", %{conn: conn} do
      doc = page(conn, "/mysteries/sorrowful/pray?form=scripture")

      assert title(doc) =~ "Pray the Sorrowful Mysteries"
      assert content(doc, ~s(meta[name="description"])) =~ "Sorrowful Mysteries"

      image = WoodcutPlate.plate("sorrowful_1")
      assert content(doc, ~s(meta[property="og:image"])) == @site <> image.src

      assert canonical(doc) == @site <> "/mysteries/sorrowful/pray"

      assert breadcrumb_names(doc) == [
               "Home",
               "The Sorrowful Mysteries",
               "Pray the Sorrowful Mysteries"
             ]
    end
  end

  describe "PageMeta" do
    test "clamp/1 leaves a short description alone and cuts a long one at a word" do
      assert PageMeta.clamp("  Short.  ") == "Short."

      long = String.duplicate("word ", 60)
      clamped = PageMeta.clamp(long)

      assert String.length(clamped) <= PageMeta.max_description()
      assert String.ends_with?(clamped, "word...")
    end

    test "every category's description fits" do
      for category <- Categories.slugs() do
        names = Enum.map(1..Categories.mystery_count(category), &"The Mystery Number #{&1}")
        opts = PageMeta.pray_category(category, names)

        assert String.length(opts[:description]) <= PageMeta.max_description()
      end
    end

    test "card/1 is the large card for a wide image and the small one for a tall one" do
      assert PageMeta.card(%{width: 1200, height: 410}) == "summary_large_image"
      assert PageMeta.card(%{width: 800, height: 1121}) == "summary"
    end

    test "plate_image/1 is nil for a mystery with no woodcut" do
      assert PageMeta.plate_image("joyful_1005") == nil
      assert PageMeta.plate_image(nil) == nil
    end
  end
end
