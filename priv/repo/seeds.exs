# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script is safe to run multiple times. It will:
# - Add any new mysteries that don't exist (based on category + order)
# - Skip existing mysteries
# - Load meditation files and let them handle their own logic
# - Create/update meditation sets as needed

alias LumenViae.Repo
alias LumenViae.Rosary.Mystery

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  LUMEN VIAE - Database Seeding")
IO.puts(String.duplicate("=", 70))
IO.puts("\nAdding any new mysteries and meditations...")

# ============================================================================
# Helper Functions
# ============================================================================

insert_mystery_if_new = fn attrs ->
  case Repo.get_by(Mystery, category: attrs.category, order: attrs.order) do
    nil ->
      mystery = Repo.insert!(struct(Mystery, attrs))
      IO.puts("  ✓ Created: #{attrs.name} (#{attrs.category} ##{attrs.order})")
      mystery

    existing ->
      IO.puts("  - Exists: #{existing.name} (#{attrs.category} ##{attrs.order})")
      existing
  end
end

# ============================================================================
# Seed Mysteries (The 15  Mysteries)
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
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "The angel Gabriel announces to Mary that she is to be the Mother of God.",
    scripture_reference: "Luke 1:26-38"
  },
  %{
    name: "The Visitation",
    category: "joyful",
    order: 2,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Mary visits her cousin Elizabeth, who proclaims her blessed among women.",
    scripture_reference: "Luke 1:39-56"
  },
  %{
    name: "The Nativity",
    category: "joyful",
    order: 3,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Jesus is born in Bethlehem and laid in a manger.",
    scripture_reference: "Luke 2:1-20"
  },
  %{
    name: "The Presentation",
    category: "joyful",
    order: 4,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Mary and Joseph present the infant Jesus in the Temple.",
    scripture_reference: "Luke 2:22-38"
  },
  %{
    name: "The Finding in the Temple",
    category: "joyful",
    order: 5,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Jesus is found in the Temple, discussing with the doctors of the Law.",
    scripture_reference: "Luke 2:41-52"
  },

  # Sorrowful Mysteries
  %{
    name: "The Agony in the Garden",
    category: "sorrowful",
    order: 1,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus suffers greatly and sweats blood in the Garden of Gethsemane.",
    scripture_reference: "Matthew 26:36-46"
  },
  %{
    name: "The Scourging at the Pillar",
    category: "sorrowful",
    order: 2,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus is bound and cruelly scourged by the Roman soldiers.",
    scripture_reference: "Matthew 27:26"
  },
  %{
    name: "The Crowning with Thorns",
    category: "sorrowful",
    order: 3,
    days_prayed: "Tuesdays and Fridays",
    description: "A crown of thorns is pressed upon Jesus' sacred head.",
    scripture_reference: "Matthew 27:27-31"
  },
  %{
    name: "The Carrying of the Cross",
    category: "sorrowful",
    order: 4,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus carries His cross to Calvary, falling three times under its weight.",
    scripture_reference: "John 19:17"
  },
  %{
    name: "The Crucifixion",
    category: "sorrowful",
    order: 5,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus is nailed to the cross and dies for our salvation.",
    scripture_reference: "John 19:18-30"
  },

  # Glorious Mysteries
  %{
    name: "The Resurrection",
    category: "glorious",
    order: 1,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Jesus rises from the dead on the third day, glorious and immortal.",
    scripture_reference: "Matthew 28:1-10"
  },
  %{
    name: "The Ascension",
    category: "glorious",
    order: 2,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Jesus ascends into Heaven forty days after His Resurrection.",
    scripture_reference: "Acts 1:6-11"
  },
  %{
    name: "The Descent of the Holy Spirit",
    category: "glorious",
    order: 3,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "The Holy Spirit descends upon Mary and the Apostles at Pentecost.",
    scripture_reference: "Acts 2:1-4"
  },
  %{
    name: "The Assumption",
    category: "glorious",
    order: 4,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Mary is taken up body and soul into Heaven.",
    scripture_reference: "Revelation 12:1"
  },
  %{
    name: "The Coronation of Mary",
    category: "glorious",
    order: 5,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Mary is crowned Queen of Heaven and Earth.",
    scripture_reference: "Revelation 12:1-6"
  },

  # Seven Sorrows of Mary
  %{
    name: "The Prophecy of Simeon",
    category: "seven_sorrows",
    order: 1,
    description: "Simeon prophesies that a sword of sorrow will pierce Mary's heart.",
    scripture_reference: "Luke 2:34-35"
  },
  %{
    name: "The Flight into Egypt",
    category: "seven_sorrows",
    order: 2,
    description: "Mary and Joseph flee with the infant Jesus to Egypt to escape Herod's persecution.",
    scripture_reference: "Matthew 2:13-21"
  },
  %{
    name: "The Loss of Jesus in the Temple",
    category: "seven_sorrows",
    order: 3,
    description: "Mary and Joseph search for three days before finding the child Jesus in the Temple.",
    scripture_reference: "Luke 2:41-50"
  },
  %{
    name: "Mary Meets Jesus on the Way to Calvary",
    category: "seven_sorrows",
    order: 4,
    description: "Mary encounters her Son carrying His cross to Calvary.",
    scripture_reference: "Luke 23:27-31"
  },
  %{
    name: "The Crucifixion and Death of Jesus",
    category: "seven_sorrows",
    order: 5,
    description: "Mary stands at the foot of the cross as Jesus dies.",
    scripture_reference: "John 19:25-27"
  },
  %{
    name: "Mary Receives the Body of Jesus",
    category: "seven_sorrows",
    order: 6,
    description: "Mary receives her Son's lifeless body taken down from the cross.",
    scripture_reference: "John 19:38-40"
  },
  %{
    name: "The Burial of Jesus",
    category: "seven_sorrows",
    order: 7,
    description: "Mary witnesses the burial of Jesus in the tomb.",
    scripture_reference: "John 19:41-42"
  }
]

Enum.each(mysteries_data, insert_mystery_if_new)

# ============================================================================
# Summary
# ============================================================================

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  Database Seeding Completed")
IO.puts(String.duplicate("=", 70))
IO.puts("\nTotal mysteries: #{Repo.aggregate(Mystery, :count)}")
IO.puts(String.duplicate("=", 70) <> "\n")
