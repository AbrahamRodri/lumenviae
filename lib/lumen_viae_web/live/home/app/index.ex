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
        "Pick the mysteries, then how to pray them: with a short reading from a saint before each decade, with a Bible verse before every Hail Mary, or with the app saying every prayer aloud with you.",
        "Before you start, one screen asks two questions. Should the app read only the meditation aloud, or every prayer? And will you count the beads on the screen, or on your own rosary?"
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
        "Each mystery has its own painting, and its meditation is read aloud in the voice you choose, at the speed you like. You can also read it instead.",
        "The meditations come from St. Alphonsus Liguori, St. John Henry Newman, Blessed Anne Catherine Emmerich, Blessed Fulton J. Sheen and others. New ones appear without updating the app."
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
      title: "Rosary beads on the screen",
      body: [
        "The whole Rosary appears as a string of beads along the edge of the screen. Swipe down to move one bead, and the next mystery begins by itself.",
        "In the Scriptural Rosary, a Bible verse appears with every Hail Mary, from the traditional Catholic English Bible (the Douay-Rheims). All 249 verses are stored in the app."
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
      title: "The Church's prayer through the day",
      body: [
        "Hours of Prayer gives you the Church's traditional prayers for eight times of day, from the night prayer to bedtime, in the form used in 1960. It opens on the prayer for right now.",
        "Today's Mass shows the traditional Latin Mass for any day, in Latin, English or both. Read the whole Mass, or only the parts that change from day to day."
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
        "Each chant comes with a recording, the sheet music, and the words in Latin and English, highlighted line by line as it plays. Everything is stored on your phone. Browse by today, season, occasion or type, or keep your favorites.",
        "\"Learn this chant\" teaches it in four steps: listen, read along, sing along, then sing on your own."
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
        "Everyday Catholic prayers in English, and in Latin too where the Church prays them in Latin: a prayer for this time of day, prayers for Mass, for Confession, for home and for times of need, and twelve more chapters.",
        "Pray a set of prayers such as Morning Prayers, the Angelus or Night Prayers one at a time, silently or aloud, and learn any prayer by heart in four steps."
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
      body: "Read the meditation instead of listening to it, then tap to begin the Hail Marys.",
      screen: %{
        name: "reader",
        alt:
          "The text reader for the Resurrection, a meditation by Blessed Fulton J. Sheen set in large type."
      }
    },
    %{
      title: "Today's Mass",
      body: "Today's traditional Latin Mass, with the Latin and the English side by side.",
      screen: %{
        name: "mass",
        alt:
          "Today's Mass for the feast of Our Lady of the Rosary, open at the prayers at the foot of the altar."
      }
    },
    %{
      title: "Consecration to Mary",
      body:
        "St. Louis de Montfort's 33 days of preparation to give yourself to Jesus through Mary, timed to end on a feast of Our Lady that you choose.",
      screen: %{
        name: "consecrate",
        alt:
          "The Consecrate tab's first page: Consecration to Mary, a 33-day preparation, under a painting of Our Lady crowned."
      }
    },
    %{
      title: "The Chapel",
      body:
        "A page you arrange yourself: your next daily prayer, what is left to pray today, your streak, reading and chant.",
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
        "Turn on the whole Rosary aloud and every prayer is spoken for you while the beads move along, so you can pray with your phone in your pocket."
    },
    %{
      title: "Without a connection",
      body:
        "Download meditations with their paintings and audio. The prayers, verses and chants are already in the app, so you can pray with no internet connection."
    },
    %{
      title: "Kept on your phone",
      body:
        "No account needed. Your journal and your prayer history stay on your phone. The app only sends an anonymous note when a Rosary is finished."
    },
    %{
      title: "Milestones, not scores",
      body:
        "The app marks the days you pray in a row with numbers that mean something in the Church: 3 days, 9 days (a novena), 33 days, and the 54-day Rosary novena. Missing a day is never held against you."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.put("/app",
       title: "Lumen Viae for iPhone",
       description:
         "Pray the Rosary on iPhone: saints' meditations read aloud, a Bible verse on every bead, the whole Rosary prayed aloud, plus chant, daily prayers and today's Mass.",
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
