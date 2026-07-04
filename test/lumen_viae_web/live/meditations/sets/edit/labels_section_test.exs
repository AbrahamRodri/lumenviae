defmodule LumenViaeWeb.Live.Meditations.Sets.Edit.LabelsSectionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LumenViaeWeb.Live.Meditations.Sets.Edit.LabelsSection

  defp render_section(labels, vocabulary \\ ["Intentions", "Saints", "Scriptural"], max_labels \\ 3) do
    render_component(&LabelsSection.labels_section/1,
      labels: labels,
      vocabulary: vocabulary,
      max_labels: max_labels
    )
  end

  test "shows the empty state when the set has no labels" do
    html = render_section([])

    assert html =~ "No labels yet"
    refute html =~ "Primary group"
  end

  test "marks the first label as the primary group and offers the rest to add" do
    html = render_section(["Saints"])
    {:ok, doc} = Floki.parse_document(html)

    assert html =~ "Primary group"

    add_buttons =
      doc
      |> Floki.find("button[phx-click=add_label]")
      |> Enum.map(&Floki.attribute(&1, "phx-value-label"))
      |> List.flatten()

    assert add_buttons == ["Intentions", "Scriptural"]
  end

  test "disables adding once the maximum is reached" do
    html =
      render_section(
        ["Intentions", "Saints", "Scriptural"],
        ["Intentions", "Saints", "Scriptural", "Contemplative"]
      )

    assert html =~ "Maximum of 3 labels reached"
    {:ok, doc} = Floki.parse_document(html)
    assert Floki.find(doc, "button[phx-click=add_label][disabled]") != []
  end
end
