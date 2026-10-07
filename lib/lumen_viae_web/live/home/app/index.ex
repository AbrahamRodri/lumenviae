defmodule LumenViaeWeb.Live.Home.App.Index do
  @moduledoc """
  The iPhone app's landing page, at `/app`.

  Every screen on it is a real screenshot of the app (4.0, the Marian Blue
  theme, the site's own colours) in `priv/static/images/app/`, and every
  feature is named as the app names it. When the app changes, retake the
  screenshot rather than describing a screen it no longer has; see
  docs/PUBLIC_SITE.md.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Home.App.PhoneScreen

  @app_store_url "https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749"

  @hero %{
    name: "home",
    alt:
      "The app's home page on a Wednesday: the Glorious Mysteries under a painting of the Resurrection, a Pray the Rosary button, and the Rosary Mysteries below."
  }

  @features [
    %{
      id: "your-rosary-today",
      kicker: "Your Rosary Today",
      title: "Three ways to pray, chosen on one page",
      body: [
        "Pick the mysteries, then the way to pray them: with a meditation from the saints between the decades, as the Scriptural Rosary with a verse for every Hail Mary, or as the Rosary Said Aloud.",
        "Before you begin, one page confirms two choices. Audio: the meditation alone, or the whole Rosary said aloud. Counting: on the screen, or on your own rosary."
      ],
      screen: %{
        name: "confirm",
        alt:
          "Your Rosary Today for Blessed Fulton J. Sheen's meditations on the Glorious Mysteries, with Audio set to Meditation Only, Counting set to On the Screen, and a Pray button."
      }
    },
    %{
      id: "meditations",
      kicker: "Meditations",
      title: "The saints' meditations, read aloud",
      body: [
        "Each mystery is set under its painting, and its meditation is read aloud in the voice you choose, at a speed you set. The text is a tap away.",
        "Meditation sets come from St. Alphonsus Liguori, St. John Henry Newman, Blessed Anne Catherine Emmerich, Blessed Fulton J. Sheen and others, and new sets arrive without an update."
      ],
      screen: %{
        name: "player",
        alt:
          "The First Glorious Mystery, the Resurrection, under a painting of the risen Christ, with the play and skip controls of its narrated meditation."
      }
    },
    %{
      id: "beads",
      kicker: "The Scriptural Rosary",
      title: "A strand of beads beside every prayer",
      body: [
        "The whole Rosary hangs as one strand of beads at the edge of the screen. Swipe down a bead at a time, and the decade turns on its own at the next Our Father.",
        "In the Scriptural Rosary a verse of the Douay-Rheims stands beside every Hail Mary: 249 verses, all kept in the app."
      ],
      screen: %{
        name: "scriptural",
        alt:
          "The Scriptural Rosary on the third Hail Mary of the Resurrection, showing Matthew 28:5 beside a strand of gold beads."
      }
    },
    %{
      id: "hours",
      kicker: "Hours of Prayer and Today's Mass",
      title: "The Church's day, hour by hour",
      body: [
        "The Hours of Prayer are the Divine Office under the 1960 rubrics: eight hours in plain names, from the Night Vigil to Bedtime Prayer, opening on the hour it is now.",
        "Today's Mass is the Daily Missal, the 1962 propers for any day, in Latin, English or both, with the whole Ordinary or the propers alone."
      ],
      screen: %{
        name: "hours",
        alt:
          "Hours of Prayer on the feast of Our Lady of the Rosary, with Evening Prayer as the prayer for now and the day's hours listed below it."
      }
    },
    %{
      id: "chant",
      kicker: "The Chant Library",
      title: "A hundred and four chants, to hear and to learn",
      body: [
        "Each chant has its recording, its score and its words in Latin and English, timed line by line and kept on the phone. Find them by Today, Seasons, Occasions, Types, Learn and Saved.",
        "Learn this chant teaches one in four steps: Listen, Read along, Sing along, On your own."
      ],
      screen: %{
        name: "chants",
        alt:
          "The Chant Library's page for today: at evening, Mary's song, the Magnificat, on an arc of the day from the Angelus to the Salve Regina."
      }
    },
    %{
      id: "prayers",
      kicker: "Prayers",
      title: "A prayer book of more than 150 prayers",
      body: [
        "The Church's common prayers in English and, where the Church prays in Latin, in Latin too: the prayer for this time of day, prayers for Mass, Confession, home and need, and twelve chapters of all the rest.",
        "Pray an order such as Morning Prayers, the Angelus or Night Prayers one prayer at a time, in silence or aloud, and learn a prayer by heart in four steps."
      ],
      screen: %{
        name: "prayers",
        alt:
          "The Prayers tab in the evening, with the Angelus under a painting of the Annunciation and a button to pray it."
      }
    }
  ]

  @also [
    %{
      title: "The meditation as text",
      body: "Read the meditation instead of hearing it, and tap on to the first Hail Mary.",
      screen: %{
        name: "reader",
        alt:
          "The text reader for the Resurrection, a meditation by Blessed Fulton J. Sheen set in large type."
      }
    },
    %{
      title: "Today's Mass",
      body: "The Mass of the day from the 1962 Missal, the Latin and the English line by line.",
      screen: %{
        name: "mass",
        alt:
          "Today's Mass for the feast of Our Lady of the Rosary, open at the prayers at the foot of the altar."
      }
    },
    %{
      title: "Consecration to Mary",
      body:
        "The 33-day preparation of St. Louis de Montfort, counted back from a Marian feast you choose.",
      screen: %{
        name: "consecrate",
        alt:
          "The Consecrate tab's first page: Consecration to Mary, a 33-day preparation, under a painting of Our Lady crowned."
      }
    },
    %{
      title: "The Chapel",
      body:
        "A page you arrange: the next of your Daily Prayers, then tiles for today, your prayer streak, reading and chant.",
      screen: %{
        name: "chapel",
        alt:
          "The Chapel tab, offering the Rosary next with a Pray the Rosary button and a Today tile listing what is left to pray."
      }
    }
  ]

  @promises [
    %{
      title: "Said aloud, start to finish",
      body:
        "With the whole Rosary said aloud, every prayer is read aloud in the voice you choose and the beads move with it, so you can pray with the phone in your pocket."
    },
    %{
      title: "Without a connection",
      body:
        "Download meditation sets with their paintings and narration. With the prayers, verses, chants and books the app carries, the Rosary prays offline."
    },
    %{
      title: "Kept on your phone",
      body:
        "No account to make. Your journal and your prayer record stay on the phone; the app sends only an anonymous note that a Rosary was finished."
    },
    %{
      title: "Milestones, not scores",
      body:
        "The days you pray are marked by the Church's own numbers: a triduum, a novena, 33 days, a Rosary novena of 54. A missed day is never held against you."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.put("/app",
       title: "Lumen Viae for iPhone",
       description:
         "The Rosary on iPhone: meditations from the saints read aloud, the Scriptural Rosary, the Rosary said aloud, with chant, the Hours and the Mass of the day.",
       image: %{
         url: PageMeta.absolute_url("/images/app/og-app.jpg"),
         width: 1200,
         height: 630,
         alt: "Three screens of the Lumen Viae iPhone app on a night-blue ground"
       }
     )
     |> assign(
       app_store_url: @app_store_url,
       hero: @hero,
       features: @features,
       also: @also,
       promises: @promises
     )}
  end

  # The download link, in the wording of Apple's badge but drawn as the
  # site's own gilt button: the official badge is licensed artwork.
  attr :href, :string, required: true

  defp app_store_button(assigns) do
    ~H"""
    <a href={@href} class="btn-gold app-store-button" rel="noopener">
      <span class="flex flex-col items-start leading-none text-left">
        <span class="text-[0.8125rem] font-medium tracking-[0.04em]">Download on the</span>
        <span class="mt-1 text-[1.375rem] font-semibold">App Store</span>
      </span>
    </a>
    """
  end
end
