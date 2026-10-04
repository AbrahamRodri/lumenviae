# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script is safe to run multiple times. It will:
# - Add any new mysteries that don't exist (based on category + order)
# - Skip existing mysteries
# - Load meditation files and let them handle their own logic
# - Create/update meditation sets as needed

alias LumenViae.Accounts
alias LumenViae.Rosary

# Seeding is an operator's job, run from a shell that already holds the
# database (`mix run`, or LumenViae.Release.seed/0 in production), so it
# writes without an actor rather than pretending to be an admin.
seed_opts = [authorize?: false]

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  LUMEN VIAE - Database Seeding")
IO.puts(String.duplicate("=", 70))
IO.puts("\nAdding any new mysteries and meditations...")

# ============================================================================
# Helper Functions
# ============================================================================

# Existing mysteries are matched on category + order, not name, so renaming a
# mystery in this file never duplicates one that is already seeded.
existing_mysteries = Map.new(Rosary.list_mysteries!(seed_opts), &{{&1.category, &1.order}, &1})

insert_mystery_if_new = fn attrs ->
  case Map.get(existing_mysteries, {attrs.category, attrs.order}) do
    nil ->
      {:ok, mystery} = Rosary.create_mystery(attrs, seed_opts)
      IO.puts("  ✓ Created: #{attrs.name} (#{attrs.category} ##{attrs.order})")
      mystery

    existing ->
      IO.puts("  - Exists: #{existing.name} (#{attrs.category} ##{attrs.order})")
      existing
  end
end

# ============================================================================
# Seed Mysteries
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 70))
IO.puts("Seeding Mysteries...")
IO.puts(String.duplicate("-", 70))

mysteries_data = [
  # Joyful Mysteries
  %{
    name: "The Annunciation",
    category: "joyful",
    order: 1,
    days_prayed: "Mondays and Thursdays, and Sundays of Advent",
    description: "The angel Gabriel announces to Mary that she is to be the Mother of God.",
    scripture_reference: "Luke 1:26-38",
    fruit: "Humility",
    key_verse:
      "Behold thou shalt conceive in thy womb, and shalt bring forth a son; and thou shalt call his name Jesus.",
    key_verse_reference: "Luke 1:31"
  },
  %{
    name: "The Visitation",
    category: "joyful",
    order: 2,
    days_prayed: "Mondays and Thursdays, and Sundays of Advent",
    description: "Mary visits her cousin Elizabeth, who proclaims her blessed among women.",
    scripture_reference: "Luke 1:39-56",
    fruit: "Love of Neighbor",
    key_verse: "Blessed art thou among women, and blessed is the fruit of thy womb.",
    key_verse_reference: "Luke 1:42"
  },
  %{
    name: "The Nativity",
    category: "joyful",
    order: 3,
    days_prayed: "Mondays and Thursdays, and Sundays of Advent",
    description: "Jesus is born in Bethlehem and laid in a manger.",
    scripture_reference: "Luke 2:1-20",
    fruit: "Poverty of Spirit",
    key_verse:
      "And she brought forth her firstborn son, and wrapped him up in swaddling clothes, and laid him in a manger.",
    key_verse_reference: "Luke 2:7"
  },
  %{
    name: "The Presentation",
    category: "joyful",
    order: 4,
    days_prayed: "Mondays and Thursdays, and Sundays of Advent",
    description: "Mary and Joseph present the infant Jesus in the Temple.",
    scripture_reference: "Luke 2:22-38",
    fruit: "Obedience",
    key_verse:
      "Now thou dost dismiss thy servant, O Lord, according to thy word in peace; because my eyes have seen thy salvation.",
    key_verse_reference: "Luke 2:29-30"
  },
  %{
    name: "The Finding in the Temple",
    category: "joyful",
    order: 5,
    days_prayed: "Mondays and Thursdays, and Sundays of Advent",
    description: "Jesus is found in the Temple, discussing with the doctors of the Law.",
    scripture_reference: "Luke 2:41-52",
    fruit: "Joy in Finding Jesus",
    key_verse: "Did you not know, that I must be about my father's business?",
    key_verse_reference: "Luke 2:49"
  },

  # Sorrowful Mysteries
  %{
    name: "The Agony in the Garden",
    category: "sorrowful",
    order: 1,
    days_prayed: "Tuesdays and Fridays, and Sundays of Lent",
    description: "Jesus suffers greatly and sweats blood in the Garden of Gethsemane.",
    scripture_reference: "Matthew 26:36-46",
    fruit: "Sorrow for Sin",
    key_verse:
      "My Father, if it be possible, let this chalice pass from me. Nevertheless not as I will, but as thou wilt.",
    key_verse_reference: "Matthew 26:39"
  },
  %{
    name: "The Scourging at the Pillar",
    category: "sorrowful",
    order: 2,
    days_prayed: "Tuesdays and Fridays, and Sundays of Lent",
    description: "Jesus is bound and cruelly scourged by the Roman soldiers.",
    scripture_reference: "Matthew 27:26",
    fruit: "Purity",
    key_verse: "Then therefore, Pilate took Jesus, and scourged him.",
    key_verse_reference: "John 19:1"
  },
  %{
    name: "The Crowning with Thorns",
    category: "sorrowful",
    order: 3,
    days_prayed: "Tuesdays and Fridays, and Sundays of Lent",
    description: "A crown of thorns is pressed upon Jesus' sacred head.",
    scripture_reference: "Matthew 27:27-31",
    fruit: "Moral Courage",
    key_verse: "And platting a crown of thorns, they put it upon his head.",
    key_verse_reference: "Matthew 27:29"
  },
  %{
    name: "The Carrying of the Cross",
    category: "sorrowful",
    order: 4,
    days_prayed: "Tuesdays and Fridays, and Sundays of Lent",
    description: "Jesus carries His cross to Calvary, falling three times under its weight.",
    scripture_reference: "John 19:17",
    fruit: "Patience",
    key_verse: "And bearing his own cross, he went forth to that place which is called Calvary.",
    key_verse_reference: "John 19:17"
  },
  %{
    name: "The Crucifixion",
    category: "sorrowful",
    order: 5,
    days_prayed: "Tuesdays and Fridays, and Sundays of Lent",
    description: "Jesus is nailed to the cross and dies for our salvation.",
    scripture_reference: "John 19:18-30",
    fruit: "Perseverance",
    key_verse: "Father, into thy hands I commend my spirit.",
    key_verse_reference: "Luke 23:46"
  },

  # Glorious Mysteries
  %{
    name: "The Resurrection",
    category: "glorious",
    order: 1,
    days_prayed: "Wednesdays and Saturdays, and Sundays outside Advent and Lent",
    description: "Jesus rises from the dead on the third day, glorious and immortal.",
    scripture_reference: "Matthew 28:1-10",
    fruit: "Faith",
    key_verse: "He is not here, for he is risen, as he said.",
    key_verse_reference: "Matthew 28:6"
  },
  %{
    name: "The Ascension",
    category: "glorious",
    order: 2,
    days_prayed: "Wednesdays and Saturdays, and Sundays outside Advent and Lent",
    description: "Jesus ascends into Heaven forty days after His Resurrection.",
    scripture_reference: "Acts 1:6-11",
    fruit: "Hope",
    key_verse:
      "And the Lord Jesus, after he had spoken to them, was taken up into heaven, and sitteth on the right hand of God.",
    key_verse_reference: "Mark 16:19"
  },
  %{
    name: "The Descent of the Holy Spirit",
    category: "glorious",
    order: 3,
    days_prayed: "Wednesdays and Saturdays, and Sundays outside Advent and Lent",
    description: "The Holy Spirit descends upon Mary and the Apostles at Pentecost.",
    scripture_reference: "Acts 2:1-4",
    fruit: "Love of God",
    key_verse:
      "And they were all filled with the Holy Ghost, and they began to speak with divers tongues.",
    key_verse_reference: "Acts 2:4"
  },
  %{
    name: "The Assumption",
    category: "glorious",
    order: 4,
    days_prayed: "Wednesdays and Saturdays, and Sundays outside Advent and Lent",
    description: "Mary is taken up body and soul into Heaven.",
    scripture_reference: "Revelation 12:1",
    fruit: "Grace of a Happy Death",
    key_verse: "He that is mighty hath done great things to me; and holy is his name.",
    key_verse_reference: "Luke 1:49"
  },
  %{
    name: "The Coronation",
    category: "glorious",
    order: 5,
    days_prayed: "Wednesdays and Saturdays, and Sundays outside Advent and Lent",
    description: "Mary is crowned Queen of Heaven and Earth.",
    scripture_reference: "Revelation 12:1-6",
    fruit: "Trust in Mary's Intercession",
    key_verse:
      "And a great sign appeared in heaven: A woman clothed with the sun, and the moon under her feet, and on her head a crown of twelve stars.",
    key_verse_reference: "Apocalypse 12:1"
  },

  # Luminous Mysteries
  #
  # Proposed by Pope St. John Paul II in 2002 and prayed on Thursdays under
  # the modern schedule. The app's daily recommendation keeps the traditional
  # schedule (Thursday remains Joyful), so these are browsable rather than
  # auto-recommended - see LumenViae.LiturgicalCalendar.
  %{
    name: "The Baptism in the Jordan",
    category: "luminous",
    order: 1,
    days_prayed: "Thursdays in the modern schedule",
    description: "Jesus is baptized in the Jordan and the voice of the Father is heard.",
    scripture_reference: "Matthew 3:13-17",
    fruit: "Openness to the Holy Spirit",
    key_verse: "This is my beloved Son, in whom I am well pleased.",
    key_verse_reference: "Matthew 3:17"
  },
  %{
    name: "The Wedding at Cana",
    category: "luminous",
    order: 2,
    days_prayed: "Thursdays in the modern schedule",
    description: "At Mary's request, Jesus works His first sign and changes water into wine.",
    scripture_reference: "John 2:1-11",
    fruit: "To Jesus through Mary",
    key_verse: "Whatsoever he shall say to you, do ye.",
    key_verse_reference: "John 2:5"
  },
  %{
    name: "The Proclamation of the Kingdom",
    category: "luminous",
    order: 3,
    days_prayed: "Thursdays in the modern schedule",
    description: "Jesus proclaims the Kingdom of God and calls all men to conversion.",
    scripture_reference: "Mark 1:14-15",
    fruit: "Repentance and Trust in God",
    key_verse:
      "The time is accomplished, and the kingdom of God is at hand: repent, and believe the gospel.",
    key_verse_reference: "Mark 1:15"
  },
  %{
    name: "The Transfiguration",
    category: "luminous",
    order: 4,
    days_prayed: "Thursdays in the modern schedule",
    description:
      "Jesus is transfigured in glory upon the mountain before Peter, James, and John.",
    scripture_reference: "Luke 9:28-36",
    fruit: "Desire for Holiness",
    key_verse: "And he was transfigured before them. And his face did shine as the sun.",
    key_verse_reference: "Matthew 17:2"
  },
  %{
    name: "The Institution of the Eucharist",
    category: "luminous",
    order: 5,
    days_prayed: "Thursdays in the modern schedule",
    description: "Jesus gives His Body and Blood under the appearances of bread and wine.",
    scripture_reference: "Matthew 26:26-28",
    fruit: "Eucharistic Adoration",
    key_verse: "Take ye, and eat. This is my body.",
    key_verse_reference: "Matthew 26:26"
  },

  # Seven Sorrows of Mary
  %{
    name: "The Prophecy of Simeon",
    category: "seven_sorrows",
    order: 1,
    days_prayed: "Fridays in Lent and September 15th",
    description: "Simeon prophesies that a sword of sorrow will pierce Mary's heart.",
    scripture_reference: "Luke 2:34-35",
    fruit: "Surrender to God's Will",
    key_verse:
      "And thy own soul a sword shall pierce, that, out of many hearts, thoughts may be revealed.",
    key_verse_reference: "Luke 2:35"
  },
  %{
    name: "The Flight into Egypt",
    category: "seven_sorrows",
    order: 2,
    days_prayed: "Fridays in Lent and September 15th",
    description:
      "Mary and Joseph flee with the infant Jesus to Egypt to escape Herod's persecution.",
    scripture_reference: "Matthew 2:13-21",
    fruit: "Trust in God's Providence",
    key_verse: "Arise, and take the child and his mother, and fly into Egypt.",
    key_verse_reference: "Matthew 2:13"
  },
  %{
    name: "The Loss of Jesus in the Temple",
    category: "seven_sorrows",
    order: 3,
    days_prayed: "Fridays in Lent and September 15th",
    description:
      "Mary and Joseph search for three days before finding the child Jesus in the Temple.",
    scripture_reference: "Luke 2:41-50",
    fruit: "Seeking Jesus Above All",
    key_verse:
      "Son, why hast thou done so to us? behold thy father and I have sought thee sorrowing.",
    key_verse_reference: "Luke 2:48"
  },
  %{
    name: "Mary Meets Jesus Carrying the Cross",
    category: "seven_sorrows",
    order: 4,
    days_prayed: "Fridays in Lent and September 15th",
    description: "Mary encounters her Son carrying His cross to Calvary.",
    scripture_reference: "Luke 23:27-31",
    fruit: "Compassion for Christ",
    key_verse:
      "And there followed him a great multitude of people, and of women, who bewailed and lamented him.",
    key_verse_reference: "Luke 23:27"
  },
  %{
    name: "The Crucifixion",
    category: "seven_sorrows",
    order: 5,
    days_prayed: "Fridays in Lent and September 15th",
    description: "Mary stands at the foot of the cross as Jesus dies.",
    scripture_reference: "John 19:25-27",
    fruit: "Standing Faithful at the Cross",
    key_verse: "Now there stood by the cross of Jesus, his mother.",
    key_verse_reference: "John 19:25"
  },
  %{
    name: "Jesus Taken Down from the Cross",
    category: "seven_sorrows",
    order: 6,
    days_prayed: "Fridays in Lent and September 15th",
    description: "Mary receives her Son's lifeless body taken down from the cross.",
    scripture_reference: "John 19:38-40",
    fruit: "Receiving Christ into Our Hearts",
    key_verse: "Joseph of Arimathea... came and took away the body of Jesus.",
    key_verse_reference: "John 19:38"
  },
  %{
    name: "The Burial of Jesus",
    category: "seven_sorrows",
    order: 7,
    days_prayed: "Fridays in Lent and September 15th",
    description: "Mary witnesses the burial of Jesus in the tomb.",
    scripture_reference: "John 19:41-42",
    fruit: "Hope in the Resurrection",
    key_verse:
      "Now there was in the place where he was crucified, a garden; and in the garden a new sepulchre... There, therefore, they laid Jesus.",
    key_verse_reference: "John 19:41-42"
  }
]

Enum.each(mysteries_data, insert_mystery_if_new)

# ============================================================================
# Development admin
# ============================================================================
#
# The admin `config :lumen_viae, :skip_admin_auth` signs in as, so the console
# runs its policies with a real actor locally. Development only: Mix is not
# even loaded in a release, and the password is random and never printed -
# nobody signs in with it, the skip does. To try the real sign-in form, turn
# the skip off and create an admin with LumenViae.Release.create_admin/1.

if Code.ensure_loaded?(Mix) and Mix.env() == :dev do
  case Accounts.get_admin_by_email(Accounts.dev_admin_email(), seed_opts) do
    {:ok, _admin} ->
      IO.puts("\n  - Exists: dev admin #{Accounts.dev_admin_email()}")

    {:error, _not_found} ->
      {:ok, _admin} =
        Accounts.create_admin(Accounts.dev_admin_email(), Accounts.generate_password(), seed_opts)

      IO.puts("\n  ✓ Created: dev admin #{Accounts.dev_admin_email()}")
  end
end

# ============================================================================
# Summary
# ============================================================================

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  Database Seeding Completed")
IO.puts(String.duplicate("=", 70))
IO.puts("\nTotal mysteries: #{Rosary.count_mysteries(seed_opts)}")
IO.puts(String.duplicate("=", 70) <> "\n")
