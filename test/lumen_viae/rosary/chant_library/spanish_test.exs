defmodule LumenViae.Rosary.ChantLibrary.SpanishTest do
  @moduledoc """
  The Chant Library's Spanish names (`priv/library/es/chant_library.json`):
  pinned, and every chant and group named in Spanish, keyed and ordered as
  the English.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.ChantLibrary.Spanish
  alias LumenViae.Rosary.Library

  # Change the file: bump its updated_at and set the new pair here. The
  # names are the team's own Spanish, listed in priv/library/es/SOURCES.md.
  @pinned {~U[2026-11-15 06:05:00Z], "ca675656c774bd77"}

  defp english(section), do: Library.served(:chant_library, section)

  test "the file is pinned by its date and words" do
    assert {Spanish.updated_at(), Spanish.file_version()} == @pinned, """
    priv/library/es/chant_library.json changed (now #{DateTime.to_iso8601(Spanish.updated_at())}, #{Spanish.file_version()}).
    Bump its updated_at and set @pinned to the new pair.
    """
  end

  test "every chant and every group has Spanish, in the English order" do
    spanish = Spanish.translation()

    assert Enum.map(spanish.chants, & &1.id) == Enum.map(english("chants"), & &1.id)
    assert Enum.map(spanish.groups, & &1.id) == Enum.map(english("groups"), & &1.id)
  end

  test "a chant has a Spanish setting exactly when it has an English one" do
    settings = Map.new(english("chants"), &{&1.id, &1.setting})

    for chant <- Spanish.translation().chants do
      assert is_binary(chant.title) and chant.title != "", chant.id

      if settings[chant.id],
        do: assert(is_binary(chant.setting) and chant.setting != "", chant.id),
        else: assert(is_nil(chant.setting), chant.id)
    end
  end

  test "the card's line reads in Spanish: the Salve's simple melody" do
    chants = Map.new(Spanish.translation().chants, &{&1.id, &1})

    assert chants["salve_regina_simple"] == %{
             id: "salve_regina_simple",
             title: "Salve Regina",
             setting: "Melodía sencilla"
           }

    assert %{title: "Señor, ten piedad", setting: "Misa de los Ángeles"} =
             chants["kyrie_de_angelis"]

    assert %{title: "Cántico de María", setting: "Con aleluya"} = chants["magnificat"]
  end

  test "a name kept in Latin is the Latin title exactly, so a client shows it once" do
    latin = Map.new(english("chants"), &{&1.id, &1.latin_title})

    for id <- ~w(salve_regina_simple ave_maris_stella tantum_ergo te_deum) do
      title = Enum.find(Spanish.translation().chants, &(&1.id == id)).title
      assert title == latin[id], id
    end
  end
end
