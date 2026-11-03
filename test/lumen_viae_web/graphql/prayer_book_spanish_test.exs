defmodule LumenViaeWeb.Graphql.PrayerBookSpanishTest do
  @moduledoc """
  GraphQL's `prayerBook(lang: "es")`: the same Spanish as
  `GET /api/v2/prayer-book?lang=es`, in `translations`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook.Current
  alias LumenViae.Rosary.PrayerBook.Spanish

  defp query(args) do
    graphql(build_conn(), """
    { prayerBook#{args} { version updatedAt prayers { id title }
        translations { id title text aiTranslated } } }
    """)
  end

  test "lang: es fills translations, and English stays as it was" do
    spanish = query(~s|(lang: "es")|)
    refute spanish["errors"]
    book = get_in(spanish, ["data", "prayerBook"])

    assert Enum.map(book["translations"], &Map.take(&1, ~w(id title text))) ==
             Enum.map(
               Spanish.prayers(),
               &%{"id" => &1.id, "title" => &1.title, "text" => &1.text}
             )

    for prayer <- book["translations"] do
      assert prayer["aiTranslated"] in [nil, true]
    end

    assert book["version"] == Current.stamp("es").version

    english = get_in(query(""), ["data", "prayerBook"])
    assert english == get_in(query(~s|(lang: "en")|), ["data", "prayerBook"])
    assert english["translations"] == []
    assert english["version"] == Library.stamp(:prayer_book).version
    assert english["prayers"] == book["prayers"]
  end
end
