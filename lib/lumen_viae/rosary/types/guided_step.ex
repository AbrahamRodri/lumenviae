defmodule LumenViae.Rosary.Types.GuidedStep do
  @moduledoc """
  One step of the guided Rosary.
  """
  use Ash.TypedStruct

  typed_struct do
    field :part, :string,
      allow_nil?: false,
      description: "The bead under the fingers (a key in `parts`)."

    field :place, :string,
      allow_nil?: false,
      description:
        "Where on the Rosary, as the app names it: \"The crucifix\", \"The Annunciation · 3 of 10\"."

    field :instruction, :string,
      allow_nil?: false,
      description: "What to do here, in plain words."

    field :prayer_ids, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The prayers said here, in order (ids in the `prayers` section); empty for a mystery's announcement."

    field :decade, :integer,
      description:
        "The decade it belongs to, from 0, or null for the opening and closing prayers."

    field :announcement, :boolean,
      allow_nil?: false,
      description: "Whether it names the mystery before its decade."

    field :closing, :boolean,
      allow_nil?: false,
      description:
        "Whether it is one of the closing prayers, after the last decade, when every bead is behind the fingers."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :guided_step
end
