defmodule LumenViae.Rosary.SpokenRosaryScriptTest do
  @moduledoc """
  The order a Rosary is said in, held to the app's: the iOS app's
  `appTests/SpokenRosaryScriptTests.swift`, ported test for test, and the
  prayer totals How to Pray teaches (`HowToPrayData.prayerCounts`). The
  script is `PrayerAudio.script/3`, expanded from the templates in
  `priv/rosary_content/script.json`.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.{Content, PrayerAudio}

  @rosaries ~w(joyful sorrowful glorious luminous)
  @extras [:holy_father, :memorare, :st_michael]

  defp orders("seven_sorrows"), do: Enum.to_list(1..7)
  defp orders(_category), do: Enum.to_list(1..5)

  defp keys(category), do: Enum.map(orders(category), &"#{category}_#{&1}")

  defp script(category, opts \\ []), do: PrayerAudio.script(category, orders(category), opts)

  # A step as one word, as the app's tests name a segment: the prayer id,
  # "announcement", "meditation" or "verse:<n>".
  defp name(%{kind: :prayer, name: id}), do: id
  defp name(%{kind: :verse, bead: n}), do: "verse:#{n}"
  defp name(%{kind: kind}), do: Atom.to_string(kind)

  defp names(steps), do: Enum.map(steps, &name/1)

  defp phase(steps, phase), do: Enum.filter(steps, &(&1.phase == phase))

  defp decade(steps, decade),
    do: Enum.filter(steps, &(&1.phase == :decade and &1.decade == decade))

  describe "the four sets of the Rosary" do
    test "open on the pendant" do
      for category <- @rosaries do
        opening = phase(script(category), :opening)

        assert names(opening) ==
                 ~w(sign_of_cross apostles_creed our_father hail_mary hail_mary hail_mary glory_be)

        assert Enum.map(opening, & &1.place) ==
                 ~w(cross cross large_bead small_bead_1 small_bead_2 small_bead_3 chain)

        assert Enum.map(opening, & &1.caption) == [
                 "The Sign of the Cross",
                 "The Apostles' Creed",
                 "The Our Father",
                 "A Hail Mary for faith",
                 "A Hail Mary for hope",
                 "A Hail Mary for charity",
                 "The Glory Be"
               ]

        assert Enum.all?(opening, &(&1.bead == 0 and &1.decade == nil and &1.mystery == nil))
      end
    end

    test "announce, meditate and pray each decade" do
      for category <- @rosaries do
        decades = phase(script(category), :decade)
        assert length(decades) == 5 * 15

        expected =
          ~w(announcement meditation our_father) ++
            List.duplicate("hail_mary", 10) ++ ~w(glory_be fatima_prayer)

        for decade <- 0..4 do
          steps = decade(decades, decade)

          assert names(steps) == expected
          assert Enum.all?(steps, &(&1.mystery == Enum.at(keys(category), decade)))

          assert steps |> Enum.filter(&(name(&1) == "hail_mary")) |> Enum.map(& &1.bead) ==
                   Enum.to_list(1..10)

          assert steps |> Enum.take(-2) |> Enum.all?(&(&1.bead == 11))
          assert Enum.all?(steps, &(&1.place == nil))
        end
      end
    end

    test "close with the Hail, Holy Queen and the closing prayer" do
      for category <- @rosaries do
        whole = script(category)
        closing = phase(whole, :closing)

        assert names(closing) == ~w(hail_holy_queen rosary_closing_prayer sign_of_cross)
        assert Enum.map(closing, & &1.place) == ~w(medal medal cross)
        assert Enum.all?(closing, &(&1.bead == 11 and &1.decade == nil))
        assert length(whole) == 7 + 75 + 3
      end
    end

    test "count every prayer as How to Pray teaches it" do
      counts = script("joyful") |> names() |> Enum.frequencies()

      assert counts["hail_mary"] == 53
      assert counts["our_father"] == 6
      assert counts["glory_be"] == 6
      assert counts["fatima_prayer"] == 5
      assert counts["announcement"] == 5
      assert counts["sign_of_cross"] == 2
      assert counts["apostles_creed"] == 1
      assert counts["hail_holy_queen"] == 1
      assert counts["rosary_closing_prayer"] == 1
      refute Map.has_key?(counts, "act_of_contrition")
      refute Map.has_key?(counts, "sorrows_closing_prayer")
    end
  end

  describe "the Seven Sorrows chaplet" do
    test "opens with the Act of Contrition" do
      opening = phase(script("seven_sorrows"), :opening)

      assert names(opening) == ~w(sign_of_cross act_of_contrition)
      assert Enum.map(opening, & &1.caption) == ["The Sign of the Cross", "The Act of Contrition"]
      assert Enum.all?(opening, &(&1.bead == 0 and &1.place == "cross"))
    end

    test "gives each sorrow seven Hail Marys and no Fatima Prayer" do
      decades = phase(script("seven_sorrows"), :decade)
      assert length(decades) == 7 * 11

      expected =
        ~w(announcement meditation our_father) ++ List.duplicate("hail_mary", 7) ++ ~w(glory_be)

      for sorrow <- 0..6 do
        steps = decade(decades, sorrow)
        assert names(steps) == expected
        assert List.last(steps).bead == 8
        assert hd(steps).caption == "The sorrow"
      end

      refute "fatima_prayer" in names(decades)
    end

    test "closes with her tears and its own prayer" do
      closing = phase(script("seven_sorrows"), :closing)

      assert names(closing) ==
               ~w(hail_mary hail_mary hail_mary sorrows_closing_prayer sign_of_cross)

      assert closing |> Enum.take(3) |> Enum.map(& &1.caption) ==
               Enum.map(1..3, &"In honor of her tears · #{&1} of 3")

      assert Enum.map(closing, & &1.place) ==
               ~w(small_bead_1 small_bead_2 small_bead_3 medal cross)

      assert Enum.all?(closing, &(&1.bead == 8))
    end

    test "takes none of the Rosary's closing prayers" do
      plain = script("seven_sorrows")
      chosen = script("seven_sorrows", closing: @extras)

      assert chosen == plain
      refute "hail_holy_queen" in names(chosen)
      refute "memorare" in names(chosen)
      refute "st_michael_prayer" in names(chosen)
      assert length(plain) == 2 + 77 + 5
    end
  end

  describe "the optional closing prayers" do
    test "follow the closing prayer in their own order" do
      closing =
        phase(script("glorious", closing: [:st_michael, :holy_father, :memorare]), :closing)

      assert names(closing) == ~w(
               hail_holy_queen rosary_closing_prayer
               our_father hail_mary glory_be
               memorare st_michael_prayer
               sign_of_cross
             )

      assert closing
             |> Enum.slice(2..4)
             |> Enum.all?(&(&1.caption == "For the Pope's intentions"))

      assert Enum.at(closing, 5).caption == "The Memorare"
      assert Enum.at(closing, 6).caption == "Prayer to Saint Michael"
    end

    test "each stands alone" do
      closing = fn extras -> script("joyful", closing: extras) |> phase(:closing) |> names() end

      assert closing.([:memorare]) ==
               ~w(hail_holy_queen rosary_closing_prayer memorare sign_of_cross)

      assert closing.([:st_michael]) ==
               ~w(hail_holy_queen rosary_closing_prayer st_michael_prayer sign_of_cross)

      assert closing.([:holy_father]) ==
               ~w(hail_holy_queen rosary_closing_prayer our_father hail_mary glory_be sign_of_cross)
    end

    test "add five steps when every one is chosen, and touch no decade" do
      plain = script("luminous")
      chosen = script("luminous", closing: @extras)

      assert length(chosen) == length(plain) + 5

      assert Enum.reject(chosen, &(&1.phase == :closing)) ==
               Enum.reject(plain, &(&1.phase == :closing))
    end
  end

  describe "the Scriptural Rosary" do
    test "says a verse before each Hail Mary, on the Hail Mary's bead" do
      for category <- ["joyful", "seven_sorrows"] do
        whole = script(category, style: :scriptural)
        hail_marys = if category == "seven_sorrows", do: 7, else: 10

        refute "meditation" in names(whole)
        assert whole |> Enum.reject(&(&1.phase == :decade)) |> Enum.all?(&(&1.kind != :verse))

        for {key, decade} <- Enum.with_index(keys(category)) do
          steps = decade(whole, decade)

          expected =
            ~w(announcement our_father) ++
              Enum.flat_map(1..hail_marys, &["verse:#{&1}", "hail_mary"]) ++
              if(category == "seven_sorrows", do: ~w(glory_be), else: ~w(glory_be fatima_prayer))

          assert names(steps) == expected

          for {%{kind: :verse} = verse, index} <- Enum.with_index(steps) do
            assert verse.name == "#{key}_#{verse.bead}"
            assert verse.caption == "Scripture · #{verse.bead} of #{hail_marys}"
            assert Enum.at(steps, index + 1).bead == verse.bead
          end
        end
      end
    end

    test "is 130 steps for the Rosary" do
      assert length(script("joyful", style: :scriptural)) == 130
      assert length(script("seven_sorrows", style: :scriptural)) == 2 + 7 * 17 + 5
    end

    test "every verse it says is one the server records" do
      for category <- ["joyful", "sorrowful", "glorious", "luminous", "seven_sorrows"],
          %{kind: :verse} = step <- script(category, style: :scriptural) do
        assert %PrayerAudio.Clip{kind: :verse} = PrayerAudio.clip_for_step(step), step.name
      end
    end
  end

  describe "the Rosary Said Aloud" do
    test "is the prayers alone, the same pendant and the same close" do
      for category <- @rosaries do
        whole = script(category, style: :plain)

        expected =
          ~w(announcement our_father) ++
            List.duplicate("hail_mary", 10) ++ ~w(glory_be fatima_prayer)

        for decade <- 0..4, do: assert(names(decade(whole, decade)) == expected)

        assert names(phase(whole, :opening)) == names(phase(script(category), :opening))

        assert names(phase(whole, :closing)) ==
                 ~w(hail_holy_queen rosary_closing_prayer sign_of_cross)

        assert length(whole) == 7 + 5 * 14 + 3
      end
    end

    test "is the chaplet's prayers alone" do
      whole = script("seven_sorrows", style: :plain, closing: @extras)
      expected = ~w(announcement our_father) ++ List.duplicate("hail_mary", 7) ++ ~w(glory_be)

      for sorrow <- 0..6, do: assert(names(decade(whole, sorrow)) == expected)

      assert names(phase(whole, :opening)) == ~w(sign_of_cross act_of_contrition)

      assert names(phase(whole, :closing)) ==
               ~w(hail_mary hail_mary hail_mary sorrows_closing_prayer sign_of_cross)
    end
  end

  describe "the app's pauses and words" do
    test "a pause follows what was said: a meditation, an announcement, a verse or a prayer" do
      pauses = %{meditation: 2000, announcement: 1200, verse: 800, prayer: 900}

      for category <- ["joyful", "seven_sorrows"],
          style <- [:meditation, :scriptural, :plain],
          step <- script(category, style: style, closing: @extras) do
        assert step.pause_ms == pauses[step.kind]
      end
    end

    test "the decade's prayers are named as the app names them" do
      steps = decade(script("sorrowful"), 0)

      assert Enum.map(steps, & &1.caption) ==
               ["The mystery", "The meditation", "The Our Father"] ++
                 Enum.map(1..10, &"Hail Mary · #{&1} of 10") ++
                 ["The Glory Be", "The Fatima Prayer"]
    end

    test "no orders, no Rosary" do
      assert PrayerAudio.script("joyful", []) == []
    end
  end

  describe "the strand" do
    test "is 56 beads for the Rosary and 57 for the chaplet, the Glory Be on the next Our Father's bead" do
      %{"rosary" => %{"strand" => rosary}, "chaplet" => %{"strand" => chaplet}} = Content.script()

      assert %{
               "decades" => 5,
               "hail_marys" => 10,
               "decade_length" => 11,
               "beads" => 56,
               "glory_be_bead" => 11
             } =
               rosary

      assert %{
               "decades" => 7,
               "hail_marys" => 7,
               "decade_length" => 8,
               "beads" => 57,
               "glory_be_bead" => 8
             } =
               chaplet

      for strand <- [rosary, chaplet] do
        assert strand["beads"] == strand["decades"] * strand["decade_length"] + 1
        assert strand["glory_be_bead"] == strand["decade_length"]
      end
    end

    test "names the chaplet's Glory Be bead without the Fatima Prayer" do
      %{"rosary" => %{"strand" => rosary}, "chaplet" => %{"strand" => chaplet}} = Content.script()

      assert rosary["labels"]["glory_be"] == "Glory Be & Fatima Prayer"
      assert rosary["label_lines"]["glory_be"] == ["Glory Be &", "Fatima Prayer"]
      assert chaplet["labels"]["glory_be"] == "Glory Be"
      assert chaplet["label_lines"]["glory_be"] == ["Glory Be"]
      assert rosary["fatima_prayer"] and not chaplet["fatima_prayer"]
    end
  end
end
