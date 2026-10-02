defmodule LumenViae.PoliciesTest do
  @moduledoc """
  Who may do what, resource by resource.

  An admin may do anything an action allows. Anybody else - the public
  site, the REST API, GraphQL, all of which run with no actor - may read
  exactly what those surfaces serve and record a completion, and nothing
  more. The `visible?` trap gets its own tests: built on authorized
  `exists`, the rule would read "no archived meditation" for a caller who
  cannot see archived meditations, and every hidden set would go public.
  """
  use LumenViae.DataCase, async: true

  alias LumenViae.Accounts
  alias LumenViae.Office.Breviary
  alias LumenViae.Rosary

  alias LumenViae.Rosary.{
    Author,
    Completion,
    Meditation,
    MeditationSet,
    Mystery,
    Narration,
    NarrationVoice,
    SetMembership,
    SpokenRosary
  }

  defp unique, do: System.unique_integer([:positive])

  defp mystery do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{name: "Mystery #{unique()}", category: "joyful", order: 100 + unique()},
        actor: admin()
      )

    mystery
  end

  defp meditation(attrs \\ %{}) do
    {:ok, meditation} =
      Rosary.create_meditation(
        Map.merge(%{content: "A meditation.", mystery_id: mystery().id}, attrs),
        actor: admin()
      )

    meditation
  end

  defp set_holding(meditations) do
    {:ok, set} =
      Rosary.create_meditation_set(%{name: "Set #{unique()}", category: "joyful"},
        actor: admin()
      )

    meditations
    |> Enum.with_index(1)
    |> Enum.each(fn {meditation, order} ->
      {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, order, actor: admin())
    end)

    set
  end

  defp archived(meditation) do
    {:ok, meditation} = Rosary.archive_meditation(meditation, actor: admin())
    meditation
  end

  defp narrate(meditation) do
    {:ok, _} =
      Rosary.record_narration(meditation, "female", "voices/female/#{unique()}.mp3",
        actor: admin()
      )

    meditation
  end

  # Three sets: one the public may see, one hidden by an archived
  # meditation, one hidden for holding nothing.
  defp sets do
    live_meditation = meditation()
    archived_meditation = meditation() |> archived()

    %{
      visible: set_holding([live_meditation]),
      hidden_by_archive: set_holding([meditation(), archived_meditation]),
      empty: set_holding([]),
      live_meditation: live_meditation,
      archived_meditation: archived_meditation
    }
  end

  defp ids(records), do: records |> Enum.map(& &1.id) |> MapSet.new()

  describe "meditation sets" do
    test "the public sees only visible sets, through any read" do
      s = sets()

      for read <- [:visible, :catalogue, :read] do
        seen = MeditationSet |> Ash.Query.for_read(read) |> Ash.read!() |> ids()

        assert s.visible.id in seen, "#{read} hides a visible set"

        refute s.hidden_by_archive.id in seen,
               "#{read} shows a set holding an archived meditation"

        refute s.empty.id in seen, "#{read} shows an empty set"
      end
    end

    test "visibility does not change with who is asking (the exists trap)" do
      s = sets()

      for actor <- [nil, admin()] do
        visible =
          MeditationSet
          |> Ash.Query.select([:id])
          |> Ash.Query.load(:visible?)
          |> Ash.read!(actor: admin())
          |> Map.new(&{&1.id, &1.visible?})

        anonymous_ids = Rosary.list_visible_meditation_sets!(actor: actor) |> ids()

        assert visible[s.visible.id]
        refute visible[s.hidden_by_archive.id]
        refute visible[s.empty.id]
        assert s.visible.id in anonymous_ids
        refute s.hidden_by_archive.id in anonymous_ids
        refute s.empty.id in anonymous_ids
      end
    end

    test "a hidden set is not found by id for the public, and found for an admin" do
      s = sets()

      assert {:error, :not_found} = Rosary.fetch_visible_meditation_set(s.hidden_by_archive.id)
      assert {:error, _} = Ash.get(MeditationSet, s.hidden_by_archive.id)
      assert {:ok, _} = Ash.get(MeditationSet, s.hidden_by_archive.id, actor: admin())

      assert Rosary.get_meditation_set_with_ordered_meditations!(s.hidden_by_archive.id,
               actor: admin()
             )
    end

    test "the admin's catalogue and hidden-set report see everything" do
      s = sets()

      catalogue = Rosary.list_meditation_sets!(actor: admin()) |> ids()

      assert MapSet.subset?(
               MapSet.new([s.visible.id, s.hidden_by_archive.id, s.empty.id]),
               catalogue
             )

      hidden = Rosary.hidden_meditation_set_ids(actor: admin())
      assert s.hidden_by_archive.id in hidden
      assert s.empty.id in hidden
      refute s.visible.id in hidden

      assert Rosary.hidden_meditation_set_ids() == MapSet.new()
    end
  end

  describe "meditations, memberships and narrations" do
    test "the public may read a meditation in circulation, not an archived one" do
      s = sets()

      assert {:ok, _} = Rosary.get_meditation(s.live_meditation.id)
      assert {:error, _} = Rosary.get_meditation(s.archived_meditation.id)
      assert {:ok, _} = Rosary.get_meditation(s.archived_meditation.id, actor: admin())

      public = Rosary.list_meditations!() |> ids()
      assert s.live_meditation.id in public
      refute s.archived_meditation.id in public
    end

    test "the public reads memberships only of sets it may see" do
      s = sets()

      assert [_] = Rosary.list_meditations_in_set(s.visible.id)
      assert [] = Rosary.list_meditations_in_set(s.hidden_by_archive.id)
      assert [_, _] = Rosary.list_meditations_in_set(s.hidden_by_archive.id, actor: admin())
    end

    test "the public reads the recordings of meditations in circulation only" do
      live = meditation() |> narrate()
      withdrawn = meditation() |> narrate() |> archived()

      public = Narration |> Ash.read!() |> Enum.map(& &1.meditation_id)
      assert live.id in public
      refute withdrawn.id in public

      all = Narration |> Ash.read!(actor: admin()) |> Enum.map(& &1.meditation_id)
      assert withdrawn.id in all
    end

    test "the pray page's read still carries every recording of a visible set" do
      narrated = meditation() |> narrate()
      set = set_holding([narrated])

      set = Rosary.get_visible_meditation_set_with_ordered_meditations!(set.id)
      assert [%{narrations: [_]}] = set.meditations
      assert [%{voice: %{slug: "female"}}] = Rosary.meditation_narrations(hd(set.meditations))
    end

    # What it answers for an archived meditation is pinned, with signing
    # stubbed, in test/lumen_viae_web/graphql/meditation_audio_test.exs.
    test "meditationAudio is open to the public" do
      assert Ash.can?({Meditation, :audio_for}, nil)
    end
  end

  describe "writes" do
    @writes [
      {Mystery, [:create, :update, :destroy]},
      {Meditation, [:create, :update, :destroy, :archive, :unarchive]},
      {MeditationSet, [:create, :update, :destroy, :record_artwork, :update_artwork_metadata]},
      {SetMembership, [:create, :update, :destroy]},
      {Narration, [:record, :destroy]},
      {Author, [:create, :update, :destroy, :record_artwork, :update_artwork_metadata]},
      {Completion, [:place, :destroy]}
    ]

    test "every write but recording a completion is the console's alone" do
      for {resource, actions} <- @writes, action <- actions do
        refute Ash.can?({resource, action}, nil),
               "anonymous may run #{inspect(resource)}.#{action}"

        assert Ash.can?({resource, action}, admin()),
               "an admin may not run #{inspect(resource)}.#{action}"
      end
    end

    test "an anonymous write through the domain is forbidden, not quietly dropped" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Rosary.create_meditation(%{content: "x", mystery_id: mystery().id})

      assert {:error, %Ash.Error.Forbidden{}} =
               Rosary.update_mystery(mystery(), %{name: "Renamed"})
    end

    test "anybody may record a completion, by either door" do
      assert Ash.can?({Completion, :record}, nil)
      assert Ash.can?({Completion, :record_from_app}, nil)

      %{visible: set} = sets()
      assert {:ok, _} = Rosary.record_completion(set.id, %{source: "web"})
    end
  end

  describe "completions" do
    test "only an admin reads them back" do
      %{visible: set} = sets()
      {:ok, _} = Rosary.record_completion(set.id, %{source: "web"})

      # Refused outright rather than answered with an empty list, so an
      # admin screen that forgot its actor fails loudly.
      assert_raise Ash.Error.Forbidden, fn -> Rosary.count_total_completions() end
      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Completion)
      assert Rosary.count_total_completions(actor: admin()) >= 1
    end

    test "the app's completion still refuses a hidden set for the public" do
      %{hidden_by_archive: set} = sets()

      assert {:error, %Ash.Error.Invalid{}} =
               Completion
               |> Ash.Changeset.for_create(:record_from_app, %{meditation_set_id: set.id})
               |> Ash.create()
    end
  end

  describe "reference data" do
    test "mysteries and authors are public reads" do
      m = mystery()
      {:ok, author} = Rosary.create_author(%{name: "Author #{unique()}"}, actor: admin())

      assert m.id in ids(Rosary.list_mysteries!())
      assert author.id in ids(Ash.read!(Author))
    end

    test "the voices and the spoken Rosary are public through their GraphQL reads only" do
      assert Ash.can?({NarrationVoice, :offered}, nil)
      assert Ash.can?({NarrationVoice, :retired}, nil)
      refute Ash.can?({NarrationVoice, :read}, nil)
      assert Ash.can?({NarrationVoice, :read}, admin())

      assert Ash.can?({SpokenRosary, :for_voice}, nil)
      refute Ash.can?({SpokenRosary, :read}, nil)
    end

    test "the Office is open to anyone" do
      for action <- [:hour, :hours, :day, :calendar, :vocabulary] do
        assert Ash.can?({Breviary, action}, nil)
      end
    end
  end

  describe "version history" do
    test "only an admin reads versions, and nobody edits them" do
      m = mystery()
      version = Module.concat(Mystery, Version)

      assert Ash.read!(version) == []
      assert [_ | _] = Ash.read!(version, actor: admin())

      for action <- [:create, :update, :destroy],
          Ash.Resource.Info.action(version, action) do
        refute Ash.can?({version, action}, admin()), "an admin may #{action} a version"
      end

      assert m
    end
  end

  describe "accounts" do
    test "the public cannot read admins, and nobody but AshAuthentication reads tokens" do
      admin = admin_fixture()

      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Accounts.Admin)
      assert admin.id in ids(Ash.read!(Accounts.Admin, actor: admin()))
      refute Ash.can?({Accounts.Admin, :create}, nil)
      refute Ash.can?({Accounts.Admin, :set_password}, nil)

      refute Ash.can?({Accounts.Token, :read}, admin())
    end

    test "not even an admin can make an admin or set a password from the web" do
      admin = admin_fixture()
      email = "planted-#{System.unique_integer([:positive])}@lumenviae.test"

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.create_admin(email, Accounts.generate_password(), actor: admin())

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.set_admin_password(admin, Accounts.generate_password(), actor: admin())

      # The shell's way still works.
      assert {:ok, _} =
               Accounts.create_admin(email, Accounts.generate_password(), authorize?: false)
    end

    test "a hashed password is never readable" do
      admin = admin_fixture()

      assert Accounts.Admin
             |> Ash.Resource.Info.attribute(:hashed_password)
             |> Map.get(:sensitive?)

      refute admin.hashed_password == password()
    end
  end
end
