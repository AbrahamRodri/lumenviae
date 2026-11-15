defmodule LumenViaeWeb.Graphql.ChantLibrarySpanishTest do
  @moduledoc """
  GraphQL's `chantLibrary(lang: "es")`: the same Spanish names as
  `GET /api/v2/chant-library?lang=es`, in `translations`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.ChantLibrary.Current
  alias LumenViae.Rosary.ChantLibrary.Spanish
  alias LumenViae.Rosary.Library

  defp query(args) do
    graphql(build_conn(), """
    { chantLibrary#{args} { version updatedAt chants { id englishTitle setting }
        translations { chants { id title setting } groups { id title } } } }
    """)
  end

  test "lang: es fills translations, and English stays as it was" do
    spanish = query(~s|(lang: "es")|)
    refute spanish["errors"]
    library = get_in(spanish, ["data", "chantLibrary"])
    expected = Spanish.translation()

    assert Enum.map(library["translations"]["chants"], &{&1["id"], &1["title"], &1["setting"]}) ==
             Enum.map(expected.chants, &{&1.id, &1.title, &1.setting})

    assert Enum.map(library["translations"]["groups"], &{&1["id"], &1["title"]}) ==
             Enum.map(expected.groups, &{&1.id, &1.title})

    assert library["version"] == Current.stamp("es").version

    english = get_in(query(""), ["data", "chantLibrary"])
    assert english == get_in(query(~s|(lang: "en")|), ["data", "chantLibrary"])
    assert english["translations"] == %{"chants" => [], "groups" => []}
    assert english["version"] == Library.stamp(:chant_library).version
    assert english["chants"] == library["chants"]
  end
end
