defmodule LumenViae.Rosary.Types.RosaryFormInfo do
  @moduledoc """
  A form of the Rosary that has a name of its own.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :string,
      allow_nil?: false,
      description:
        "`scriptural` or `holy` (the Rosary Said Aloud), the iOS app's names for the forms."

    field :name, :string,
      allow_nil?: false,
      description: "The form's name wherever it is shown."

    field :recorded_as, :string,
      allow_nil?: false,
      description:
        "What the Prayer Record keeps a prayer of this form under. It is the old name for the Rosary Said Aloud, because the record already holds days under it; a client that wants its history readable beside the iOS app's keeps the same."

    field :kicker, :string,
      allow_nil?: false,
      description: "The line over the name on the form's own page."

    field :subtitle, :string,
      allow_nil?: false,
      description: "The line under the name on the form's own page."

    field :detail, :string,
      allow_nil?: false,
      description: "The line under the name where the form is listed under Ways to Pray."

    field :about, :string,
      allow_nil?: false,
      description: "What the form is, on the page's ledger."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :rosary_form_info
end
