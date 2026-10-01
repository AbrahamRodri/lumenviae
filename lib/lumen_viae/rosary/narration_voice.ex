defmodule LumenViae.Rosary.NarrationVoice do
  @moduledoc """
  A narration voice as the GraphQL API serves it.

  Voices are configuration, not rows (see `LumenViae.Rosary.Voices`), so
  this resource has no table: every read is answered from config by
  `LumenViae.Rosary.NarrationVoice.FromConfig`, loaded into Ash's in-memory
  data layer so that ordinary filters and sorts apply.

  Two reads. `:offered` is what `GET /api/voices` lists: the voices a
  client may pick, default first. `:retired` is the voices taken out of
  the pickers, each with the voice that now answers for it, so a client can
  move a stored choice on without that mapping being compiled into it.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    extensions: [AshGraphql.Resource]

  alias LumenViae.Rosary.NarrationVoice.FromConfig

  graphql do
    type :narration_voice
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :read do
      primary? true
      description "Every configured voice, offered or retired, in config order."
      prepare FromConfig
      prepare build(sort: [position: :asc])
    end

    read :offered do
      description "The voices a listener may choose, the default first."
      prepare FromConfig
      filter expr(retired == false)
      prepare build(sort: [position: :asc])
    end

    read :retired do
      description "Voices no longer offered, each with the voice that now answers for it."
      prepare FromConfig
      filter expr(retired == true)
      prepare build(sort: [position: :asc])
    end
  end

  attributes do
    attribute :slug, :string do
      primary_key? true
      allow_nil? false
      public? true
      description "What a client stores and sends back, as in ?voice=female."
    end

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true

    attribute :default, :boolean do
      allow_nil? false
      public? true
      description "The voice heard when a client names none. Exactly one offered voice is."
    end

    attribute :retired, :boolean, allow_nil?: false, public?: true

    attribute :replaced_by, :string do
      public? true
      description "For a retired voice, the slug of the voice a request for it is served by."
    end

    # Config order, which is the order the pickers show.
    attribute :position, :integer, allow_nil?: false
  end
end
