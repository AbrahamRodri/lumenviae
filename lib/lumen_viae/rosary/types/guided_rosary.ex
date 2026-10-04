defmodule LumenViae.Rosary.Types.GuidedRosary do
  @moduledoc """
  "Your First Rosary": the Rosary a step at a time, each step tied to the bead under the fingers, as `GET /api/v2/rosary-content` serves it in its `guided_rosary` section. The words and the order are the iOS app's, from `priv/rosary_content/guided_rosary.json`.
  """
  use Ash.TypedStruct

  alias LumenViae.Rosary.Types

  typed_struct do
    field :devotion_name, :string,
      allow_nil?: false,
      description:
        "How the prayer record names a Rosary prayed with the guide: \"A Guided Rosary\". It counts as the day's Rosary."

    field :first_kept_step, :integer,
      allow_nil?: false,
      description:
        "The first step (from 0) at which a place is worth keeping, and leaving asks first: the Our Father on the first large bead."

    field :parts, {:array, :string},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "Every bead of a rosary, in the order the fingers travel them: `crucifix`, `pendantLarge.0`, `pendantSmall.0`-`.2`, `pendantLarge.1`, the loop (`loopSmall.<decade>.<bead>`, decades and beads from 0, with `loopLarge.0`-`.3` between the tens), and `medal`. A step's `part` and an anatomy's `parts` are these keys, which never change."

    field :anatomy, {:array, Types.RosaryAnatomy},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description: "The parts of a rosary as a beginner learns them."

    field :rosaries, {:array, Types.GuidedMysteries},
      allow_nil?: false,
      constraints: [nil_items?: false],
      description:
        "The steps for each set the guide can walk: the Joyful, Sorrowful, Glorious and Luminous. The Seven Sorrows chaplet is not guided."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :guided_rosary
end
