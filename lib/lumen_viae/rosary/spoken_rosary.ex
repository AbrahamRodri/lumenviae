defmodule LumenViae.Rosary.SpokenRosary do
  @moduledoc """
  One voice's spoken Rosary as the GraphQL API serves it: the same
  recordings as `GET /api/rosary/audio`, from `LumenViae.Rosary.PrayerAudio`.

  There is no table. `:for_voice` answers with one record for the voice
  asked for (or the default, or a retired voice's successor), carrying the
  catalogue's `version` and the earliest moment any URL in the response
  expires. Each kind of clip is a calculation, and Ash computes only the
  calculations a query selects - so the selection set does the job REST's
  `?include=` does, and a client that asks for the prayers alone has no
  verse signed on its behalf.
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    extensions: [AshGraphql.Resource]

  alias LumenViae.Rosary.SpokenRosary.Clips
  alias LumenViae.Rosary.SpokenRosary.ForVoice
  alias LumenViae.Rosary.Types

  graphql do
    type :spoken_rosary
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :read do
      primary? true
      get? true
      description "The default voice's spoken Rosary."
      prepare ForVoice
    end

    read :for_voice do
      get? true
      description "One voice's spoken Rosary. Without a voice, the default voice's."

      argument :voice, :string do
        description "The voice preferred, a slug. A retired voice is answered by its successor and an unknown one by the default; `voice` in the answer is the one served."
      end

      prepare ForVoice
    end
  end

  attributes do
    attribute :voice, :string do
      primary_key? true
      allow_nil? false
      public? true

      description "The voice actually served, which differs from the one asked for when that one is retired."
    end

    attribute :version, :string do
      allow_nil? false
      public? true

      description "Fingerprints every file in the voice's catalogue: a device whose pack has the same version holds every current recording."
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? true
      description "The earliest moment any URL in this response stops working."
    end
  end

  calculations do
    calculate :prayers, {:array, Types.RosaryClip}, {Clips, kind: :prayer} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "The fixed prayers, in the order they are said."
    end

    calculate :announcements, {:array, Types.AnnouncementClip}, {Clips, kind: :announcement} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "One announcement per mystery."
    end

    calculate :verses, {:array, Types.VerseGroup}, {Clips, kind: :verse} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "The Scriptural Rosary: each mystery's verses in bead order."
    end

    calculate :book, {:array, Types.RosaryClip}, {Clips, kind: :book} do
      allow_nil? false
      public? true
      constraints nil_items?: false
      description "The Prayer Book's prayers."
    end
  end
end
