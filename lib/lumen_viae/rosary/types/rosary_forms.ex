defmodule LumenViae.Rosary.Types.RosaryForms do
  @moduledoc """
  The `forms` section: the Rosary's three forms, the Audio and Counting choices and what each form's page offers. See docs/JSON_API.md, "The content document".
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :forms, {:array, Types.RosaryFormInfo},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The two forms with a name of their own: the Scriptural Rosary and the Rosary Said Aloud. The third form, a meditation set, is named by the set."

    field :choices, {:array, Types.RosaryChoice},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The two choices that change how the Rosary is prayed, Audio and Counting."

    field :offered, {:array, Types.RosaryFormRule},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Which choices a form's page offers, by choice id, while the Audio choice is Whole Rosary (`when_aloud`) and while it is not (`when_silent`)."

    field :rows, {:array, Types.RosaryFormRule},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Which rows a form's page carries beneath the choices, by row id, in the same two cases."

    field :row_titles, {:array, Types.RosaryRowTitle},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "What each row is called."

    field :holy_audio_value, :string,
      allow_nil?: false,
      description: "What the Rosary Said Aloud's audio row says, as a fact rather than a choice."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_forms
end
