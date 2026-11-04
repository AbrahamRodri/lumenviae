defmodule LumenViaeWeb.Graphql.ConsecrationSpanishTest do
  @moduledoc """
  GraphQL's `consecration(lang: "es")`: the same Spanish as
  `GET /api/v2/consecration?lang=es`, in `translations`.
  """
  use LumenViaeWeb.ConnCase, async: true

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary.Consecration.Current
  alias LumenViae.Rosary.Consecration.Spanish
  alias LumenViae.Rosary.Library

  defp query(args) do
    graphql(build_conn(), """
    { consecration#{args} { version updatedAt days { number title }
        translations {
          phases { id name subtitle aiTranslated }
          days { number title journalPrompt aiTranslated
                 readings { order title text source aiTranslated } }
          prayers { id title text aiTranslated }
          feasts { id name description aiTranslated } } } }
    """)
  end

  test "lang: es fills translations, and English stays as it was" do
    spanish = query(~s|(lang: "es")|)
    refute spanish["errors"]
    consecration = get_in(spanish, ["data", "consecration"])
    translations = consecration["translations"]
    expected = Spanish.translation()

    assert Enum.map(translations["days"], & &1["number"]) == Enum.map(expected.days, & &1.number)

    assert Enum.map(translations["days"], fn day ->
             Enum.map(day["readings"], &{&1["order"], &1["text"]})
           end) ==
             Enum.map(expected.days, fn day -> Enum.map(day.readings, &{&1.order, &1.text}) end)

    assert Enum.map(translations["prayers"], &{&1["id"], &1["text"]}) ==
             Enum.map(expected.prayers, &{&1.id, &1.text})

    assert Enum.map(translations["phases"], & &1["name"]) == Enum.map(expected.phases, & &1.name)
    assert Enum.map(translations["feasts"], & &1["name"]) == Enum.map(expected.feasts, & &1.name)

    assert consecration["version"] == Current.stamp("es").version

    english = get_in(query(""), ["data", "consecration"])
    assert english == get_in(query(~s|(lang: "en")|), ["data", "consecration"])

    assert english["translations"] == %{
             "phases" => [],
             "days" => [],
             "prayers" => [],
             "feasts" => []
           }

    assert english["version"] == Library.stamp(:consecration).version
    assert english["days"] == consecration["days"]
  end
end
