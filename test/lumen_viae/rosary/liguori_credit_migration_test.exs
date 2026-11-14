defmodule LumenViae.Rosary.LiguoriCreditMigrationTest do
  @moduledoc """
  `20261110150000_credit_liguori_glories_of_mary.exs`, run on rows shaped
  as production holds sets 28 to 30 since 7 Nov 2026: their credit becomes
  the 1902 Glories of Mary, the Finding in the Temple takes the 1902
  wording, nothing else changes, and down puts every row back.
  """
  use LumenViae.DataCase, async: false

  alias LumenViae.Repo
  alias LumenViae.Rosary

  @path "priv/repo/migrations/20261110150000_credit_liguori_glories_of_mary.exs"
  @method "Traditional method of the Rosary, from 19th-century Catholic prayer books"
  @glories "The Glories of Mary (Benziger, 1902), Meditations for the Rosary"

  @finding """
  Let us contemplate in this mystery,
  how the Blessed Virgin Mary, after having lost her beloved Son in Jerusalem, sought him for the space of three days; and at length found him in the temple, in the midst of the doctors, disputing with them, being of the age of twelve years.

  O most Blessed Virgin, more than martyr in thy sufferings ...\
  """

  defp statements(part) do
    [up, down] = @path |> File.read!() |> String.split("def down do")
    source = if part == :up, do: up, else: down
    for [_, sql] <- Regex.scan(~r/execute """\n(.*?)\n\s*"""/s, source), do: sql
  end

  # The test database has run every migration already, so its (empty)
  # backup tables exist: drop them inside this test's transaction first.
  defp run(:up = part) do
    Repo.query!("DROP TABLE IF EXISTS meditation_glories_before_20261110")
    Repo.query!("DROP TABLE IF EXISTS meditation_set_glories_before_20261110")
    for sql <- statements(part), do: Repo.query!(sql)
    :ok
  end

  defp run(part) do
    for sql <- statements(part), do: Repo.query!(sql)

    if part == :down do
      Repo.query!("DROP TABLE meditation_glories_before_20261110")
      Repo.query!("DROP TABLE meditation_set_glories_before_20261110")
    end

    :ok
  end

  defp set_and_meditation(content) do
    {:ok, mystery} =
      Rosary.create_mystery(
        %{
          name: "M #{System.unique_integer([:positive])}",
          category: "joyful",
          order: System.unique_integer([:positive])
        },
        actor: admin()
      )

    {:ok, set} =
      Rosary.create_meditation_set(
        %{
          name: "Liguori #{System.unique_integer([:positive])}",
          category: "joyful",
          source: @method,
          description:
            "A short reflection and prayer for each Joyful Mystery, from the traditional method of the Rosary printed in 19th-century Catholic prayer books."
        },
        actor: admin()
      )

    {:ok, meditation} =
      Rosary.create_meditation(
        %{
          content: content,
          author: "St. Alphonsus Liguori",
          source: @method,
          mystery_id: mystery.id
        },
        actor: admin()
      )

    {:ok, _} = Rosary.add_meditation_to_set(set.id, meditation.id, 1, actor: admin())
    {set, meditation}
  end

  defp row(table, id) do
    %{rows: [row], columns: columns} =
      Repo.query!("SELECT * FROM #{table} WHERE id = $1", [id])

    Map.new(Enum.zip(columns, row))
  end

  test "credits the 1902 edition and gives the Finding its 1902 words; down undoes it" do
    {set, finding} = set_and_meditation(@finding)
    {_other_set, other} = set_and_meditation("Let us contemplate in this mystery how ...")

    {:ok, untouched} =
      Rosary.create_meditation(
        %{content: "c", source: "Some other book", mystery_id: finding.mystery_id},
        actor: admin()
      )

    before = {row("meditations", finding.id), row("meditation_sets", set.id)}

    run(:up)

    finding_after = row("meditations", finding.id)
    assert finding_after["source"] == @glories

    assert finding_after["content"] =~
             "after having lost (through no fault of hers) her beloved Son"

    assert finding_after["content"] =~
             "sitting in the midst of the doctors, hearing them and asking them questions, being of the age of twelve years."

    refute finding_after["content"] =~ "disputing"
    assert row("meditations", finding.id)["author"] == "St. Alphonsus Liguori"

    assert row("meditations", other.id)["source"] == @glories
    assert row("meditations", other.id)["content"] == "Let us contemplate in this mystery how ..."
    assert row("meditations", untouched.id)["source"] == "Some other book"

    set_after = row("meditation_sets", set.id)
    assert set_after["source"] == @glories

    assert set_after["description"] ==
             "A short reflection and prayer for each Joyful Mystery, from The Glories of Mary (Benziger, 1902), Meditations for the Rosary."

    run(:down)

    {finding_before, set_before} = before
    assert row("meditations", finding.id)["content"] == finding_before["content"]
    assert row("meditations", finding.id)["source"] == @method
    assert row("meditation_sets", set.id)["description"] == set_before["description"]
    assert row("meditation_sets", set.id)["source"] == @method
  end
end
