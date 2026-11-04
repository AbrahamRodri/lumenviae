defmodule LumenViaeWeb.Graphql.MeditationSetsSpanishTest do
  @moduledoc """
  GraphQL's `meditationSet(id:, lang: "es")`: the same Spanish as
  `GET /api/v2/meditation-sets/:id?lang=es`, in `translations`.
  """
  use LumenViaeWeb.ConnCase, async: false

  import LumenViaeWeb.GraphqlHelpers

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Meditation.Spanish

  setup do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "GQL ES Mystery #{System.unique_integer([:positive])}",
          category: "joyful",
          order: 100 + rem(System.unique_integer([:positive]), 100_000),
          scripture_reference: "Luke 1:26-38"
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{name: "GQL ES Set #{System.unique_integer([:positive])}", category: "joyful"},
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        %{title: "The Annunciation", content: "The English.", mystery_id: mystery.id},
        actor: admin()
      )

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())

    previous = Application.get_env(:lumen_viae, Spanish)

    Application.put_env(:lumen_viae, Spanish,
      entries: %{
        "#{meditation.id}" => %{
          "title" => "La Anunciación",
          "content" => "En español.",
          "english" => Spanish.fingerprint(meditation.title, meditation.content),
          "ai_translated" => true
        }
      }
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:lumen_viae, Spanish, previous),
        else: Application.delete_env(:lumen_viae, Spanish)
    end)

    %{set: set, meditation: meditation}
  end

  defp query(set, args) do
    graphql(build_conn(), """
    { meditationSet(id: #{set.id}#{args}) { id name translations { id title content aiTranslated } } }
    """)
  end

  test "lang: es fills translations; English stays as it was", %{set: set, meditation: meditation} do
    spanish = query(set, ~s|, lang: "es"|)
    refute spanish["errors"]

    assert get_in(spanish, ["data", "meditationSet", "translations"]) == [
             %{
               "id" => meditation.id,
               "title" => "La Anunciación",
               "content" => "En español.",
               "aiTranslated" => true
             }
           ]

    english = query(set, "")
    assert english == query(set, ~s|, lang: "en"|)
    assert get_in(english, ["data", "meditationSet", "translations"]) == []

    assert get_in(english, ["data", "meditationSet", "name"]) ==
             get_in(spanish, ["data", "meditationSet", "name"])
  end
end
