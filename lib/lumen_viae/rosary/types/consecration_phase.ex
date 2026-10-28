defmodule LumenViae.Rosary.Types.ConsecrationPhase do
  @moduledoc """
  One phase of the 33-day Consecration, as `GET /api/v2/consecration`
  serves it: its days and the prayers said on each of them.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description: "The phase's id (`knowledge_of_self`). Stable forever."

    field :name, :string,
      allow_nil?: false,
      description: "What the phase is called on screen (`Days 1–12`, `Week 1`)."

    field :subtitle, :string,
      allow_nil?: false,
      description: "What the phase is for (`Knowing Yourself`)."

    field :first_day, :integer, allow_nil?: false, description: "Its first day, counting from 1."
    field :last_day, :integer, allow_nil?: false, description: "Its last day."

    field :painting, :string,
      allow_nil?: false,
      description:
        "The app's painting that heads the phase's days (`luminous_baptism`), the same name in both apps' bundles."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The prayers said on each of its days, in order. Every id is one of the document's prayers."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_phase
end
