defmodule LumenViae.Rosary.RosaryContentSectionsTest do
  @moduledoc """
  The sections of the Rosary's content keyed by a mystery - `mysteries`,
  `categories` and `verses` - and the two data migrations that give the
  `mysteries` table the app's names, fruits and key verses.

  What the app shows is `test/support/fixtures/app_mysteries.json`, copied
  from the iOS app's Swift. It is never edited to make a test pass.

  Not async: the migrations match rows on the real keys, `joyful_1` to
  `seven_sorrows_7`, which other tests insert too, and two async tests that
  insert the same unique keys in another order deadlock.
  """
  use LumenViae.DataCase, async: false

  alias LumenViae.Rosary
  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.PrayerAudio
  alias LumenViae.Rosary.RosaryContent
  alias LumenViae.Rosary.RosaryContent.Current

  @fixture "test/support/fixtures/app_mysteries.json" |> File.read!() |> Jason.decode!()
  @app Map.new(@fixture["mysteries"], &{&1["key"], &1})

  # What production held on 19 August 2026 for the six it renames, and on 3
  # October through the live API.
  @production_names %{
    "glorious_5" => "The Coronation of Mary",
    "luminous_1" => "The Baptism of Jesus",
    "seven_sorrows_4" => "Mary Meets Jesus on the Way to Calvary",
    "seven_sorrows_5" => "Jesus Dies on the Cross",
    "seven_sorrows_6" => "Mary Receives the Dead Body of Jesus in Her Arms",
    "seven_sorrows_7" => "Jesus is Placed in the Tomb"
  }

  @migrations [
    "priv/repo/migrations/20261004021200_fill_mystery_fruits_and_key_verses.exs",
    "priv/repo/migrations/20261004021300_align_mystery_names_with_the_app.exs"
  ]

  # Each section that is fixed in code, with each {updated_at, version} it
  # has been served at, oldest first. Change what a section serves: move its
  # @updated_at and add the new pair at the end of its list here.
  @history %{
    categories: [
      {~U[2026-10-04 00:00:00Z], "d29c9a26a3a64014"},
      {~U[2026-10-04 03:00:00Z], "bb54d4b8158c254d"}
    ],
    verses: [{~U[2026-10-04 00:00:00Z], "9dc68b86b1bd0730"}]
  }

  # The `up` statements of a migration, run as they would be on deploy.
  defp migrate_up do
    for path <- @migrations do
      source = File.read!(path)
      [up, _down] = String.split(source, "def down do")

      for [_, sql] <- Regex.scan(~r/execute """\n(.*?)\n\s*"""/s, up) do
        Repo.query!(sql)
      end
    end

    :ok
  end

  # The 27 rows as production holds them before the migrations: its names,
  # and no fruit or key verse.
  defp production_rows do
    for key <- Categories.mystery_keys() do
      [category, order] = Regex.run(~r/^(.+)_(\d)$/, key, capture: :all_but_first)

      {:ok, mystery} =
        Rosary.create_mystery(
          %{
            name: Map.get(@production_names, key, @app[key]["name"]),
            category: category,
            order: String.to_integer(order)
          },
          actor: admin()
        )

      mystery
    end
  end

  defp by_key do
    Rosary.list_mysteries!(actor: admin(), load: [:key]) |> Map.new(&{&1.key, &1})
  end

  defp section(name) do
    RosaryContent
    |> Ash.Query.for_read(:current)
    |> Ash.Query.load(name)
    |> Ash.read_one!()
    |> Map.fetch!(name)
  end

  describe "the migrations" do
    test "give every mystery the app's name, fruit and key verse" do
      production_rows()
      migrate_up()

      mysteries = by_key()

      for {key, app} <- @app do
        mystery = Map.fetch!(mysteries, key)
        assert mystery.name == app["name"], key
        assert mystery.fruit == app["fruit"], key
        assert mystery.key_verse == app["key_verse"], key
        assert mystery.key_verse_reference == app["key_verse_reference"], key
      end
    end

    test "change nothing when run again" do
      production_rows()
      migrate_up()
      Repo.query!("UPDATE mysteries SET updated_at = '2001-01-01 00:00:00'")
      before = by_key()

      migrate_up()

      assert by_key() == before
    end

    test "never overwrite a value set in the console, or a name changed since" do
      production_rows()

      {:ok, _} =
        by_key()
        |> Map.fetch!("joyful_1")
        |> Rosary.update_mystery(%{fruit: "A fruit of our own"}, actor: admin())

      {:ok, _} =
        by_key()
        |> Map.fetch!("glorious_5")
        |> Rosary.update_mystery(%{name: "The Crowning of Our Lady"}, actor: admin())

      migrate_up()

      mysteries = by_key()
      assert mysteries["joyful_1"].fruit == "A fruit of our own"
      assert mysteries["joyful_1"].key_verse == @app["joyful_1"]["key_verse"]
      assert mysteries["glorious_5"].name == "The Crowning of Our Lady"
      assert mysteries["glorious_5"].fruit == @app["glorious_5"]["fruit"]
    end

    test "leave a row outside the app's 27 alone" do
      production_rows()

      {:ok, extra} =
        Rosary.create_mystery(
          %{name: "Jesus is Placed in the Tomb", category: "seven_sorrows", order: 8},
          actor: admin()
        )

      migrate_up()

      {:ok, extra} = Rosary.get_mystery(extra.id, actor: admin())
      assert extra.name == "Jesus is Placed in the Tomb"
      assert extra.fruit == nil
      assert extra.key_verse == nil
    end
  end

  describe "the mysteries section" do
    setup do
      production_rows()
      migrate_up()
      :ok
    end

    test "serves the app's 27 mysteries, once each, in the order they are prayed" do
      mysteries = section(:mysteries)
      keys = Enum.map(mysteries, & &1.key)

      assert length(keys) == 27
      assert keys == Enum.uniq(keys)
      assert keys == Categories.mystery_keys()
      assert keys == Enum.map(@fixture["mysteries"], & &1["key"])
    end

    test "with the app's names, fruits and key verses" do
      for mystery <- section(:mysteries) do
        app = @app[mystery.key]

        assert {mystery.name, mystery.fruit, mystery.key_verse, mystery.key_verse_reference} ==
                 {app["name"], app["fruit"], app["key_verse"], app["key_verse_reference"]}
      end
    end

    test "each with the announcement the spoken Rosary records, byte for byte" do
      recorded = Map.new(PrayerAudio.announcements(), &{&1.mystery, &1.text})

      for mystery <- section(:mysteries) do
        assert mystery.announcement == Map.fetch!(recorded, mystery.key)
      end
    end

    test "a row whose key the app does not know is not served" do
      {:ok, _} =
        Rosary.create_mystery(%{name: "Extra", category: "joyful", order: 6}, actor: admin())

      refute "joyful_6" in Enum.map(section(:mysteries), & &1.key)
    end
  end

  describe "the version" do
    setup do
      production_rows()
      migrate_up()
      :ok
    end

    test "moves when a curator edits a mystery, and the date with it" do
      before = Current.stamp()
      Repo.query!("UPDATE mysteries SET updated_at = '2001-01-01 00:00:00'")
      assert Current.stamp().version == before.version

      {:ok, _} =
        by_key()
        |> Map.fetch!("sorrowful_3")
        |> Rosary.update_mystery(%{fruit: "Courage"}, actor: admin())

      after_edit = Current.stamp()
      refute after_edit.version == before.version
      assert DateTime.compare(after_edit.updated_at, RosaryContent.Categories.updated_at()) == :gt
    end

    test "is the same on every read of unchanged content" do
      assert Current.stamp() == Current.stamp()
    end
  end

  describe "the categories section" do
    test "the five, in the order the app presents them" do
      categories = section(:categories)

      assert Enum.map(categories, & &1.slug) == Categories.slugs()

      assert Enum.map(categories, &{&1.name, &1.devotion_title, &1.hail_marys, &1.fatima_prayer}) ==
               [
                 {"Joyful", "Joyful Mysteries", 10, true},
                 {"Sorrowful", "Sorrowful Mysteries", 10, true},
                 {"Glorious", "Glorious Mysteries", 10, true},
                 {"Luminous", "Luminous Mysteries", 10, true},
                 {"Seven Sorrows", "Seven Sorrows of Mary", 7, false}
               ]
    end

    test "each devotion title is the label the console and the site use" do
      for category <- section(:categories) do
        assert category.devotion_title == Categories.label(category.slug)
      end
    end

    test "label each mystery as its announcement does" do
      announcements = PrayerAudio.announcements()

      labels =
        for category <- section(:categories),
            {label, order} <- Enum.with_index(category.mystery_labels, 1),
            do: {"#{category.slug}_#{order}", label}

      assert Enum.map(labels, &elem(&1, 0)) == Categories.mystery_keys()

      for {key, label} <- labels do
        announcement = Enum.find(announcements, &(&1.mystery == key))
        assert String.starts_with?(announcement.text, label <> ": "), key
      end
    end

    test "the seven graces of the Seven Sorrows, as the app has them, and none for the others" do
      for category <- section(:categories) do
        expected = if category.slug == "seven_sorrows", do: @fixture["seven_graces"], else: []
        assert category.graces == expected
      end
    end
  end

  describe "the verses section" do
    test "249 verses, ten to a mystery and seven to a sorrow, in bead order" do
      groups = section(:verses)

      assert Enum.map(groups, & &1.key) == Categories.mystery_keys()

      for group <- groups do
        expected = if String.starts_with?(group.key, "seven_sorrows"), do: 7, else: 10
        assert Enum.map(group.verses, & &1.bead) == Enum.to_list(1..expected), group.key
      end

      assert groups |> Enum.flat_map(& &1.verses) |> length() == 249
    end

    test "exactly the words the spoken Rosary says" do
      served =
        for group <- section(:verses), verse <- group.verses do
          {group.key, verse.bead, verse.reference, verse.text}
        end

      assert served ==
               Enum.map(PrayerAudio.verses(), &{&1.mystery, &1.bead, &1.reference, &1.text})
    end
  end

  describe "every section moves the version" do
    test "each section the document serves is folded into its stamp" do
      served =
        RosaryContent
        |> Ash.Resource.Info.public_calculations()
        |> Enum.map(&to_string(&1.name))
        |> Enum.sort()

      assert served == Enum.sort(Current.folded_sections())
    end
  end

  describe "the fixed sections are dated" do
    test "each is dated and versioned as its history last records it" do
      for {name, module, value} <- [
            {:categories, RosaryContent.Categories, RosaryContent.Categories.fixed()},
            {:verses, RosaryContent.Verses, RosaryContent.Verses.groups()}
          ] do
        {pinned_at, pinned_version} = List.last(@history[name])
        version = Content.version(%{"value" => plain(value)})

        assert {module.updated_at(), version} == {pinned_at, pinned_version}, """
        The #{name} section changed (now #{DateTime.to_iso8601(module.updated_at())}, #{version}).
        Move @updated_at in #{inspect(module)} and add the new pair to @history here.
        """
      end
    end
  end

  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  defp plain(struct) when is_struct(struct),
    do: struct |> Map.from_struct() |> Map.new(fn {k, v} -> {k, plain(v)} end)

  defp plain(value), do: value
end
