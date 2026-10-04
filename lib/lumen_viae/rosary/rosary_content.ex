defmodule LumenViae.Rosary.RosaryContent do
  @moduledoc """
  The Rosary's words as one document, for a client that prays offline:
  `GET /api/v2/rosary-content` and GraphQL's `rosaryContent`. The words
  are `LumenViae.Rosary.Content`'s, and the `schedule` section is
  `LumenViae.LiturgicalCalendar`'s and the `labels` section is
  `LumenViae.Rosary.Labels`'s.

  There is no table. `:current` answers with the one document there is,
  carrying a `version` that fingerprints everything it serves and the
  moment it last changed. Each section is a calculation, and Ash computes
  only the calculations a query selects: the bare request carries the
  version and the date alone, which is how a device asks whether its
  saved copy is current, and a client names the sections it wants in
  `fields[rosary_content]=` (GraphQL: the selection set).
  """
  use Ash.Resource,
    domain: LumenViae.Rosary,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias LumenViae.Rosary.RosaryContent.Categories
  alias LumenViae.Rosary.RosaryContent.Current
  alias LumenViae.Rosary.RosaryContent.Forms
  alias LumenViae.Rosary.RosaryContent.Labels
  alias LumenViae.Rosary.RosaryContent.Learn
  alias LumenViae.Rosary.RosaryContent.Milestones
  alias LumenViae.Rosary.RosaryContent.Mysteries
  alias LumenViae.Rosary.RosaryContent.Prayers
  alias LumenViae.Rosary.RosaryContent.Quotes
  alias LumenViae.Rosary.RosaryContent.Reminders
  alias LumenViae.Rosary.RosaryContent.Schedule
  alias LumenViae.Rosary.RosaryContent.Script
  alias LumenViae.Rosary.RosaryContent.Verses
  alias LumenViae.Rosary.Types

  graphql do
    type :rosary_content
    encode_primary_key? false
    derive_filter? false
    derive_sort? false
  end

  # The sections are not defaults: a client names those it wants in
  # fields[rosary_content]=, so asking whether its copy is current costs
  # two short fields.
  json_api do
    type "rosary_content"
    default_fields [:version, :updated_at]
    derive_filter? false
    derive_sort? false
  end

  actions do
    read :current do
      primary? true
      get? true
      description "The Rosary's words as one document. There is only ever one."
      prepare Current
    end
  end

  policies do
    bypass LumenViae.Accounts.Checks.ActorIsAdmin do
      authorize_if always()
    end

    policy action(:current) do
      authorize_if always()
    end
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      description "Always `current`: there is one document."
    end

    attribute :version, :string do
      allow_nil? false
      public? true

      description "Fingerprints everything the document serves: a device whose copy has the same version holds every current word. Compare it; do not parse it."
    end

    attribute :updated_at, :utc_datetime do
      allow_nil? false
      public? true
      description "When the content last changed."
    end
  end

  calculations do
    calculate :prayers, {:array, Types.RosaryPrayer}, Prayers do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The twelve prayers of the Rosary and the Seven Sorrows chaplet, in the order they are said, in English and Latin."
    end

    calculate :learn, Types.RosaryLearn, {Learn, section: :learn} do
      allow_nil? false
      public? true

      description "The How to Pray course: three lessons, then \"Your First Rosary\", with the steps of the Rosary and the prayers said at each, how often each prayer comes round, Montfort's counsel and the questions beginners ask."
    end

    calculate :guided_rosary, Types.GuidedRosary, {Learn, section: :guided_rosary} do
      allow_nil? false
      public? true

      description "\"Your First Rosary\": the Rosary a step at a time for each of the four sets, every step tied to the bead under the fingers, with the parts of a rosary as a beginner learns them."
    end

    calculate :schedule, Types.RosarySchedule, Schedule do
      allow_nil? false
      public? true

      description "Which mysteries a day calls for, on both weekly schedules, as rules to apply offline: each weekday's set, Sunday's by season, every Lent and Advent from last year to three years ahead, the home grid's order and the days each set is prayed in words. The day is the device's calendar day, turning at midnight, not the prayer day that turns at four in the morning."
    end

    calculate :script, Types.ScriptTemplates, Script do
      allow_nil? false
      public? true

      description "The order a Rosary is said in, as templates a client expands offline: the Rosary's and the chaplet's steps, the optional prayers after the Rosary and the strand's beads. GET /api/v2/rosary-script expands them."
    end

    calculate :mysteries, {:array, Types.RosaryMystery}, Mysteries do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The 27 mysteries in the order they are prayed, by category (Joyful, Sorrowful, Glorious, Luminous, the Seven Sorrows) and then by place, each keyed `<category>_<order>`, with its fruit, key verse and the spoken Rosary's announcement."
    end

    calculate :categories, {:array, Types.RosaryCategory}, Categories do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The five categories of mysteries, in the order the app presents them: names, the label of each mystery by position, Hail Marys per decade, whether the Fatima Prayer is said, and the Seven Sorrows' graces."
    end

    calculate :verses, {:array, Types.RosaryVerses}, Verses do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The Scriptural Rosary's verses as text, each mystery's in bead order: ten to a mystery, seven to a sorrow. The words the spoken Rosary says."
    end

    calculate :quotes, Types.RosaryQuotes, Quotes do
      allow_nil? false
      public? true

      description "The daily quotations on the Rosary, and the rule that chooses one for a day: the home screen's, and a second one for after praying, half the catalogue away."
    end

    calculate :milestones, {:array, Types.RosaryMilestone}, Milestones do
      allow_nil? false
      public? true
      constraints nil_items?: false

      description "The streak's named devotional milestones, by days ascending. One is reached when a day's first prayer brings the streak to exactly its days."
    end

    calculate :reminders, Types.RosaryReminders, Reminders do
      allow_nil? false
      public? true

      description "The daily reminders' messages in their groups, what each intention draws from, and the numbers of the rule that picks a week of them."
    end

    calculate :labels, Types.RosaryLabels, Labels do
      allow_nil? false
      public? true

      description "The meditation set labels, what the app calls each and the kinds of meditation they describe."
    end

    calculate :forms, Types.RosaryForms, Forms do
      allow_nil? false
      public? true

      description "The Rosary's forms (the Scriptural Rosary, the Rosary Said Aloud), the Audio and Counting choices in their words, and what each form's page offers."
    end
  end
end
