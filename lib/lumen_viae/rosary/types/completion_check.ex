defmodule LumenViae.Rosary.Types.CompletionCheck do
  @moduledoc """
  What a completion would record, answered by `Completion`'s
  `:check_record_from_app` without recording it: the set, whether it was
  prayed aloud, and the app it would be counted for.
  """
  use Ash.TypedStruct

  typed_struct do
    field :meditation_set_id, :integer,
      allow_nil?: false,
      description: "The set it would be recorded for: one the public can see."

    field :prayed_aloud, :boolean, description: "Whether it was prayed aloud, as sent, or null."

    field :source, :string,
      allow_nil?: false,
      description: "The app it would be counted for, `ios` or `android`, from the user agent."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :completion_check
end
