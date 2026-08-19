defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.ArtworkSectionTest do
  @moduledoc """
  Drives the artwork card on the set edit page.

  Nothing here uploads: a real upload would put an object in a real bucket
  depending on which environment variables happen to be set. The upload path
  is covered by `LumenViae.Curation.ArtworkUploadTest`; what is checked here
  is everything around it - the focal point, the publish gate, the crops and
  the details form.
  """
  use LumenViaeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LumenViae.Rosary

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{admin_authenticated: true})}
  end

  defp create_set(attrs \\ %{}) do
    defaults = %{name: "Artwork Set #{System.unique_integer([:positive])}", category: "sorrowful"}
    {:ok, set} = Rosary.create_meditation_set(Map.merge(defaults, attrs))
    set
  end

  defp with_artwork(set, metadata \\ %{}) do
    attrs =
      Map.merge(
        %{
          "image_key" => "sets/#{set.id}/8f21c4d9e0b3a7f6.jpg",
          "image_width" => 1600,
          "image_height" => 2400
        },
        metadata
      )

    {:ok, set} = Rosary.update_meditation_set_artwork(set, attrs)
    set
  end

  defp described(set) do
    with_artwork(set, %{
      "image_alt" => "Christ falls beneath the cross.",
      "image_license" => "public_domain"
    })
  end

  defp edit(conn, set), do: live(conn, "/admin/meditation-sets/#{set.id}/edit")

  describe "a set with no artwork" do
    test "offers an upload and shows no crops", %{conn: conn} do
      {:ok, _view, html} = edit(conn, create_set())

      assert html =~ "Upload a painting"
      refute html =~ "Set detail hero"
      refute html =~ "Focal point"
    end

    test "states the rules so a painting is not rejected after the wait", %{conn: conn} do
      {:ok, _view, html} = edit(conn, create_set())

      assert html =~ "JPEG"
      assert html =~ "12 MB"
      assert html =~ "1200px"
      assert html =~ "CMYK"
    end
  end

  describe "a set with artwork" do
    test "shows the painting, the focal picker and all three crops", %{conn: conn} do
      set = described(create_set())

      {:ok, _view, html} = edit(conn, set)

      assert html =~ "Focal point"
      assert html =~ "Set detail hero"
      assert html =~ "Home card"
      assert html =~ "Mini player"
      assert html =~ "phx-hook=\"FocalPoint\""
      assert html =~ "sets/#{set.id}/8f21c4d9e0b3a7f6.jpg"
      assert html =~ "Replace the painting"
    end

    # phx-update="ignore" here left a replaced painting showing the old image
    # while the crops beside it showed the new one, because the <img> is a
    # child of this container and children of an ignored element are never
    # patched.
    test "leaves the focal picker patchable so a replacement painting appears", %{conn: conn} do
      {:ok, _view, html} = edit(conn, described(create_set()))

      {:ok, doc} = Floki.parse_document(html)
      [target] = Floki.find(doc, "#focal-target")

      assert Floki.attribute(target, "phx-hook") == ["FocalPoint"]
      assert Floki.attribute(target, "phx-update") == []
    end

    test "the upload limit the form enforces is the one the rules state", %{conn: conn} do
      {:ok, _view, html} = edit(conn, create_set())

      assert html =~
               "at most #{div(LumenViae.Curation.ArtworkUpload.max_bytes(), 1024 * 1024)} MB"
    end

    test "frames every crop from the stored focal point", %{conn: conn} do
      {:ok, set} =
        Rosary.update_meditation_set_artwork_metadata(described(create_set()), %{
          "image_focal_y" => 0.24
        })

      {:ok, _view, html} = edit(conn, set)

      assert html =~ "object-position: 50.0% 24.0%"
    end

    # The publish gate is enforced in the API view, so the only place a
    # curator can learn about it is here.
    test "warns when the painting is saved but not being served", %{conn: conn} do
      {:ok, _view, html} = edit(conn, with_artwork(create_set()))

      assert html =~ "not being served"
      assert html =~ "description and a licence"
    end

    test "drops the warning once it has a description and a licence", %{conn: conn} do
      {:ok, _view, html} = edit(conn, described(create_set()))

      refute html =~ "not being served"
    end
  end

  describe "moving the focal point" do
    test "persists what the hook pushes", %{conn: conn} do
      set = described(create_set())
      {:ok, view, _html} = edit(conn, set)

      render_hook(view, "set_focal_point", %{"x" => 0.5, "y" => 0.24})

      reloaded = Rosary.get_meditation_set!(set.id)
      assert reloaded.image_focal_x == 0.5
      assert reloaded.image_focal_y == 0.24
    end

    test "repaints the crops from the new point", %{conn: conn} do
      {:ok, view, _html} = edit(conn, described(create_set()))

      html = render_hook(view, "set_focal_point", %{"x" => 0.5, "y" => 0.24})

      assert html =~ "object-position: 50.0% 24.0%"
    end

    test "nudges by a hundredth in each direction", %{conn: conn} do
      set = described(create_set())
      {:ok, view, _html} = edit(conn, set)

      view |> element("button[phx-value-axis=y][phx-value-delta='-0.01']") |> render_click()

      assert Rosary.get_meditation_set!(set.id).image_focal_y == 0.49
    end

    test "stops nudging at the edge of the canvas", %{conn: conn} do
      set = described(create_set())
      {:ok, view, _html} = edit(conn, set)

      render_hook(view, "set_focal_point", %{"x" => 0.5, "y" => 0.0})
      view |> element("button[phx-value-axis=y][phx-value-delta='-0.01']") |> render_click()

      assert Rosary.get_meditation_set!(set.id).image_focal_y == 0.0
    end

    # Float.parse rather than String.to_float: the latter raises on any
    # integer-looking string, which would take the whole LiveView down.
    test "survives an integer-looking delta", %{conn: conn} do
      set = described(create_set())
      {:ok, view, _html} = edit(conn, set)

      assert render_hook(view, "nudge_focal", %{"axis" => "y", "delta" => "1"})
      assert Rosary.get_meditation_set!(set.id).image_focal_y == 1.0
    end

    test "ignores a delta that is not a number at all", %{conn: conn} do
      set = described(create_set())
      {:ok, view, _html} = edit(conn, set)

      assert render_hook(view, "nudge_focal", %{"axis" => "y", "delta" => "down"})
      assert Rosary.get_meditation_set!(set.id).image_focal_y == 0.5
    end
  end

  describe "the artwork details form" do
    test "saves the description, attribution and licence", %{conn: conn} do
      set = with_artwork(create_set())
      {:ok, view, _html} = edit(conn, set)

      view
      |> form("form[phx-submit=update_artwork_meta]",
        artwork: %{
          image_alt: "Christ falls beneath the cross on the road out of the city.",
          image_title: "Christ Carrying the Cross",
          image_artist: "El Greco",
          image_year: "c. 1580",
          image_source_url: "https://www.metmuseum.org/art/collection/search/436574",
          image_license: "public_domain"
        }
      )
      |> render_submit()

      reloaded = Rosary.get_meditation_set!(set.id)

      assert reloaded.image_alt =~ "Christ falls"
      assert reloaded.image_title == "Christ Carrying the Cross"
      assert reloaded.image_artist == "El Greco"
      assert reloaded.image_year == "c. 1580"
      assert reloaded.image_license == "public_domain"
    end

    # The form must not be able to repoint a set at another object, whatever
    # it posts.
    test "cannot touch the key or the dimensions", %{conn: conn} do
      set = with_artwork(create_set())
      {:ok, view, _html} = edit(conn, set)

      render_submit(view, "update_artwork_meta", %{
        "artwork" => %{
          "image_key" => "sets/1/somebody-elses.jpg",
          "image_width" => "10",
          "image_artist" => "El Greco"
        }
      })

      reloaded = Rosary.get_meditation_set!(set.id)

      assert reloaded.image_key == "sets/#{set.id}/8f21c4d9e0b3a7f6.jpg"
      assert reloaded.image_width == 1600
      assert reloaded.image_artist == "El Greco"
    end

    test "reports a rejected licence rather than saving it", %{conn: conn} do
      set = with_artwork(create_set())
      {:ok, view, _html} = edit(conn, set)

      html =
        render_submit(view, "update_artwork_meta", %{
          "artwork" => %{"image_license" => "probably_fine"}
        })

      assert html =~ "Failed to save the artwork details"
      assert Rosary.get_meditation_set!(set.id).image_license == nil
    end

    test "says so when the details still leave the artwork unserved", %{conn: conn} do
      set = with_artwork(create_set())
      {:ok, view, _html} = edit(conn, set)

      html =
        render_submit(view, "update_artwork_meta", %{
          "artwork" => %{"image_artist" => "El Greco"}
        })

      assert html =~ "not served yet"
    end
  end

  describe "the set's own byline" do
    test "saves an author and source alongside the other set details", %{conn: conn} do
      set = create_set()
      {:ok, view, _html} = edit(conn, set)

      view
      |> form("form[phx-submit=update_meditation_set]",
        meditation_set: %{
          name: set.name,
          category: set.category,
          author: "Bl. Anne Catherine Emmerich",
          source: "The Dolorous Passion of Our Lord Jesus Christ"
        }
      )
      |> render_submit()

      reloaded = Rosary.get_meditation_set!(set.id)

      assert reloaded.author == "Bl. Anne Catherine Emmerich"
      assert reloaded.source == "The Dolorous Passion of Our Lord Jesus Christ"
    end

    test "explains what happens when the byline is left blank", %{conn: conn} do
      {:ok, _view, html} = edit(conn, create_set())

      assert html =~ "every one of them agrees"
    end
  end
end
