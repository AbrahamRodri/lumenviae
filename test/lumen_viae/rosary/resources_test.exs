defmodule LumenViae.Rosary.ResourcesTest do
  @moduledoc """
  The Ash resources and the Ecto contexts they are replacing sit on the
  same tables. While both exist, this checks that they agree: a row written
  by one is read by the other with the same values and the same Elixir
  types, and the database's own constraints come back from Ash as
  validation errors rather than crashes.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Rosary

  alias LumenViae.Rosary.{
    Author,
    Completion,
    Meditation,
    MeditationSet,
    Mystery,
    Narration,
    SetMembership
  }

  @resources [Mystery, Meditation, MeditationSet, SetMembership, Completion, Author, Narration]

  defp mystery_fixture(attrs \\ %{}) do
    {:ok, mystery} =
      attrs
      |> Enum.into(%{
        name: "The Annunciation",
        category: "joyful",
        order: 1,
        days_prayed: "Monday, Saturday",
        description: "The angel Gabriel is sent to Mary.",
        scripture_reference: "Luke 1:26-38"
      })
      |> Rosary.create_mystery()

    mystery
  end

  defp meditation_fixture(mystery, attrs \\ %{}) do
    {:ok, meditation} =
      attrs
      |> Enum.into(%{
        title: "On the Annunciation",
        content: "  The angel came in unto her.\n\nShe was troubled at his saying.\n",
        author: "St. Alphonsus Liguori",
        source: "The Glories of Mary",
        mystery_id: mystery.id,
        audio_url: "Joyful-Liguori-1.mp3",
        tts_annotations: [%{"offset" => 12, "seconds" => 1.5}]
      })
      |> Rosary.create_meditation()

    meditation
  end

  defp set_fixture(attrs \\ %{}) do
    {:ok, set} =
      attrs
      |> Enum.into(%{name: "Liguori", category: "joyful", labels: ["Saints", "Scriptural"]})
      |> Rosary.create_meditation_set()

    set
  end

  defp create!(resource, attrs) do
    resource |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!()
  end

  describe "the domain" do
    # Only the table-backed resources: the domain also holds resources with
    # no data layer (the GraphQL API's narration voices and spoken Rosary),
    # which map no table.
    test "registers all seven table-backed resources" do
      table_backed =
        Rosary
        |> Ash.Domain.Info.resources()
        |> Enum.filter(&(Ash.DataLayer.data_layer(&1) == AshPostgres.DataLayer))

      assert Enum.sort(table_backed) == Enum.sort(@resources)
    end

    test "every resource declares its GraphQL type" do
      types = Map.new(@resources, &{&1, AshGraphql.Resource.Info.type(&1)})

      assert types == %{
               Mystery => :mystery,
               Meditation => :meditation,
               MeditationSet => :meditation_set,
               SetMembership => :set_membership,
               Completion => :completion,
               Author => :author,
               Narration => :narration
             }
    end

    test "ids are integers" do
      for resource <- @resources do
        assert Ash.Resource.Info.attribute(resource, :id).type == Ash.Type.Integer
      end
    end

    # The iOS app never pages, so a read that returned one page unasked
    # would quietly drop the rest of a list. The default read can paginate
    # when a caller asks it to; it must never do so on its own.
    test "no read paginates unless it is asked to" do
      for resource <- @resources do
        case Ash.Resource.Info.primary_action!(resource, :read).pagination do
          false ->
            :ok

          pagination ->
            refute pagination.required?, "#{inspect(resource)} requires pagination"
            refute pagination.paginate_by_default?, "#{inspect(resource)} paginates by default"
        end
      end

      mystery = mystery_fixture()
      for n <- 1..3, do: meditation_fixture(mystery, %{audio_url: "m#{n}.mp3"})

      assert [_, _, _] = Ash.read!(Meditation)
    end
  end

  describe "rows written by the Ecto contexts" do
    test "a mystery reads back the same through Ash" do
      mystery = mystery_fixture()
      read = Ash.get!(Mystery, mystery.id)

      for field <- ~w(id name category order days_prayed description scripture_reference)a do
        assert Map.fetch!(read, field) == Map.fetch!(mystery, field), "#{field} differs"
      end

      assert read.inserted_at == mystery.inserted_at
      assert read.updated_at == mystery.updated_at
      assert %NaiveDateTime{microsecond: {0, 0}} = read.inserted_at
    end

    test "a meditation keeps its untrimmed content, its annotations and its archive stamp" do
      meditation = mystery_fixture() |> meditation_fixture()
      {:ok, archived} = Rosary.archive_meditation(meditation)

      read = Ash.get!(Meditation, meditation.id)

      assert read.content == meditation.content
      assert read.tts_annotations == [%{"offset" => 12, "seconds" => 1.5}]
      assert read.audio_url == "Joyful-Liguori-1.mp3"
      assert read.mystery_id == meditation.mystery_id
      assert read.archived_at == archived.archived_at
      assert %DateTime{time_zone: "Etc/UTC"} = read.archived_at
    end

    test "a set keeps its labels in order and its focal point as floats" do
      set = set_fixture()
      read = Ash.get!(MeditationSet, set.id)

      assert read.labels == ["Saints", "Scriptural"]
      assert read.image_focal_x === 0.5
      assert read.image_focal_y === 0.5
      assert read.author_id == nil
    end

    test "a completion and a narration read back the same" do
      mystery = mystery_fixture()
      meditation = meditation_fixture(mystery)
      set = set_fixture()

      {:ok, completion} =
        Rosary.record_completion(set.id, %{
          source: "ios",
          time_zone: "America/Chicago",
          locale: "en_US",
          prayed_aloud: true
        })

      {:ok, _meditation} = Rosary.record_narration(meditation, "female", "voices/female/a.mp3")

      read = Ash.get!(Completion, completion.id)
      assert read.meditation_set_id == set.id
      assert read.completed_at == completion.completed_at
      assert read.source == "ios"
      assert read.time_zone == "America/Chicago"
      assert read.prayed_aloud == true

      assert [narration] = Ash.read!(Narration)
      assert narration.meditation_id == meditation.id
      assert narration.voice == "female"
      assert narration.s3_key == "voices/female/a.mp3"
      assert %DateTime{} = narration.generated_at
    end
  end

  describe "rows written by Ash" do
    test "are read by the Ecto contexts with second-precision timestamps" do
      mystery =
        create!(Mystery, %{
          name: "The Visitation",
          category: "joyful",
          order: 2,
          scripture_reference: "Luke 1:39-56"
        })

      assert is_integer(mystery.id)
      assert mystery.inserted_at == mystery.updated_at

      fetched = Rosary.get_mystery!(mystery.id)
      assert fetched.name == "The Visitation"
      assert fetched.order == 2
      assert fetched.inserted_at == mystery.inserted_at
      assert %NaiveDateTime{microsecond: {0, 0}} = fetched.inserted_at
    end

    test "a meditation defaults its annotations and keeps content verbatim" do
      mystery = mystery_fixture()
      content = "\n  First paragraph.\n\nSecond paragraph.  \n"

      meditation = create!(Meditation, %{content: content, mystery_id: mystery.id})

      fetched = Rosary.get_meditation!(meditation.id)
      assert fetched.content == content
      assert fetched.tts_annotations == []
      assert fetched.archived_at == nil
    end

    test "a set gets the column defaults" do
      set = create!(MeditationSet, %{name: "Emmerich", category: "sorrowful"})

      fetched = Rosary.get_meditation_set!(set.id)
      assert fetched.labels == []
      assert fetched.image_focal_x === 0.5
      assert fetched.image_focal_y === 0.5
    end

    test "the default accept lists leave the managed columns out of reach" do
      mystery = mystery_fixture()

      assert {:error, %Ash.Error.Invalid{}} =
               Meditation
               |> Ash.Changeset.for_create(:create, %{
                 content: "Text.",
                 mystery_id: mystery.id,
                 archived_at: DateTime.utc_now()
               })
               |> Ash.create()

      assert {:error, %Ash.Error.Invalid{}} =
               MeditationSet
               |> Ash.Changeset.for_create(:create, %{
                 name: "Set",
                 category: "joyful",
                 image_key: "sets/1/anything.jpg"
               })
               |> Ash.create()
    end
  end

  describe "relationships" do
    setup do
      mystery = mystery_fixture()
      first = meditation_fixture(mystery, %{title: "First", audio_url: "a.mp3"})
      second = meditation_fixture(mystery, %{title: "Second", audio_url: "b.mp3"})
      {:ok, author} = Rosary.create_author(%{name: "St. Alphonsus Liguori"})
      set = set_fixture(%{author_id: author.id})

      {:ok, _} = Rosary.add_meditation_to_set(set.id, first.id, 2)
      {:ok, _} = Rosary.add_meditation_to_set(set.id, second.id, 1)
      {:ok, _} = Rosary.record_narration(first, "female", "voices/female/a.mp3")
      {:ok, _} = Rosary.record_completion(set.id)

      %{mystery: mystery, first: first, second: second, author: author, set: set}
    end

    test "a set reaches its meditations, memberships, author and completions", ctx do
      set =
        MeditationSet
        |> Ash.get!(ctx.set.id)
        |> Ash.load!([:meditations, :set_memberships, :author_profile, :completions])

      assert set.meditations |> Enum.map(& &1.id) |> Enum.sort() ==
               Enum.sort([ctx.first.id, ctx.second.id])

      assert set.set_memberships |> Enum.map(&{&1.meditation_id, &1.order}) |> Enum.sort() ==
               Enum.sort([{ctx.first.id, 2}, {ctx.second.id, 1}])

      assert set.author_profile.id == ctx.author.id
      assert [%Completion{}] = set.completions
    end

    test "a meditation reaches its mystery, narrations and sets", ctx do
      meditation =
        Meditation
        |> Ash.get!(ctx.first.id)
        |> Ash.load!([:mystery, :narrations, :meditation_sets])

      assert meditation.mystery.id == ctx.mystery.id
      assert [%Narration{voice: "female"}] = meditation.narrations
      assert [%MeditationSet{id: set_id}] = meditation.meditation_sets
      assert set_id == ctx.set.id
    end

    test "a mystery reaches its meditations and an author their sets", ctx do
      mystery = Mystery |> Ash.get!(ctx.mystery.id) |> Ash.load!(:meditations)
      assert length(mystery.meditations) == 2

      author = Author |> Ash.get!(ctx.author.id) |> Ash.load!(:meditation_sets)
      assert [%MeditationSet{id: set_id}] = author.meditation_sets
      assert set_id == ctx.set.id
    end
  end

  describe "the existing unique indexes" do
    test "come back as validation errors, not crashes" do
      mystery = mystery_fixture()
      meditation = meditation_fixture(mystery)
      set = set_fixture()
      {:ok, _} = Rosary.create_author(%{name: "Blessed Anne Catherine Emmerich"})
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1)
      {:ok, _} = Rosary.record_narration(meditation, "female", "voices/female/a.mp3")
      other = meditation_fixture(mystery, %{audio_url: "other.mp3"})

      duplicates = [
        {Mystery, %{name: "Again", category: "joyful", order: 1}},
        {Author, %{name: "Blessed Anne Catherine Emmerich"}},
        {SetMembership, %{meditation_set_id: set.id, meditation_id: meditation.id, order: 2}},
        {SetMembership, %{meditation_set_id: set.id, meditation_id: other.id, order: 1}},
        {Narration,
         %{
           meditation_id: meditation.id,
           voice: "female",
           s3_key: "voices/female/b.mp3",
           generated_at: DateTime.utc_now()
         }}
      ]

      for {resource, attrs} <- duplicates do
        assert {:error, %Ash.Error.Invalid{errors: [error | _]}} =
                 resource |> Ash.Changeset.for_create(:create, attrs) |> Ash.create()

        assert error.message == "has already been taken",
               "#{inspect(resource)} #{inspect(attrs)} gave #{inspect(error)}"
      end
    end

    test "a missing parent is a validation error too" do
      assert {:error, %Ash.Error.Invalid{}} =
               Meditation
               |> Ash.Changeset.for_create(:create, %{content: "Text.", mystery_id: -1})
               |> Ash.create()
    end
  end
end
