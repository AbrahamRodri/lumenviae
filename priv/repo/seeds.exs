# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     LumenViae.Repo.insert!(%LumenViae.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias LumenViae.Repo
alias LumenViae.Rosary.Mystery

# Clear existing mysteries
Repo.delete_all(Mystery)

# Joyful Mysteries (Mondays, Thursdays, and Saturdays)
Repo.insert!(%Mystery{
  name: "The Annunciation",
  category: "joyful",
  order: 1,
  days_prayed: "Mondays, Thursdays, and Saturdays",
  description: "The angel Gabriel announces to Mary that she is to be the Mother of God.",
  scripture_reference: "Luke 1:26-38"
})

Repo.insert!(%Mystery{
  name: "The Visitation",
  category: "joyful",
  order: 2,
  days_prayed: "Mondays, Thursdays, and Saturdays",
  description: "Mary visits her cousin Elizabeth, who proclaims her blessed among women.",
  scripture_reference: "Luke 1:39-56"
})

Repo.insert!(%Mystery{
  name: "The Nativity",
  category: "joyful",
  order: 3,
  days_prayed: "Mondays, Thursdays, and Saturdays",
  description: "Jesus is born in Bethlehem and laid in a manger.",
  scripture_reference: "Luke 2:1-20"
})

Repo.insert!(%Mystery{
  name: "The Presentation",
  category: "joyful",
  order: 4,
  days_prayed: "Mondays, Thursdays, and Saturdays",
  description: "Mary and Joseph present the infant Jesus in the Temple.",
  scripture_reference: "Luke 2:22-38"
})

Repo.insert!(%Mystery{
  name: "The Finding in the Temple",
  category: "joyful",
  order: 5,
  days_prayed: "Mondays, Thursdays, and Saturdays",
  description: "Jesus is found in the Temple, discussing with the doctors of the Law.",
  scripture_reference: "Luke 2:41-52"
})

# Sorrowful Mysteries (Tuesdays and Fridays)
Repo.insert!(%Mystery{
  name: "The Agony in the Garden",
  category: "sorrowful",
  order: 1,
  days_prayed: "Tuesdays and Fridays",
  description: "Jesus suffers greatly and sweats blood in the Garden of Gethsemane.",
  scripture_reference: "Matthew 26:36-46"
})

Repo.insert!(%Mystery{
  name: "The Scourging at the Pillar",
  category: "sorrowful",
  order: 2,
  days_prayed: "Tuesdays and Fridays",
  description: "Jesus is bound and cruelly scourged by the Roman soldiers.",
  scripture_reference: "Matthew 27:26"
})

Repo.insert!(%Mystery{
  name: "The Crowning with Thorns",
  category: "sorrowful",
  order: 3,
  days_prayed: "Tuesdays and Fridays",
  description: "A crown of thorns is pressed upon Jesus' sacred head.",
  scripture_reference: "Matthew 27:27-31"
})

Repo.insert!(%Mystery{
  name: "The Carrying of the Cross",
  category: "sorrowful",
  order: 4,
  days_prayed: "Tuesdays and Fridays",
  description: "Jesus carries His cross to Calvary, falling three times under its weight.",
  scripture_reference: "John 19:17"
})

Repo.insert!(%Mystery{
  name: "The Crucifixion",
  category: "sorrowful",
  order: 5,
  days_prayed: "Tuesdays and Fridays",
  description: "Jesus is nailed to the cross and dies for our salvation.",
  scripture_reference: "John 19:18-30"
})

# Glorious Mysteries (Wednesdays, Thursdays, and Sundays)
Repo.insert!(%Mystery{
  name: "The Resurrection",
  category: "glorious",
  order: 1,
  days_prayed: "Wednesdays, Thursdays, and Sundays",
  description: "Jesus rises from the dead on the third day, glorious and immortal.",
  scripture_reference: "Matthew 28:1-10"
})

Repo.insert!(%Mystery{
  name: "The Ascension",
  category: "glorious",
  order: 2,
  days_prayed: "Wednesdays, Thursdays, and Sundays",
  description: "Jesus ascends into Heaven forty days after His Resurrection.",
  scripture_reference: "Acts 1:6-11"
})

Repo.insert!(%Mystery{
  name: "The Descent of the Holy Spirit",
  category: "glorious",
  order: 3,
  days_prayed: "Wednesdays, Thursdays, and Sundays",
  description: "The Holy Spirit descends upon Mary and the Apostles at Pentecost.",
  scripture_reference: "Acts 2:1-4"
})

Repo.insert!(%Mystery{
  name: "The Assumption",
  category: "glorious",
  order: 4,
  days_prayed: "Wednesdays, Thursdays, and Sundays",
  description: "Mary is taken up body and soul into Heaven.",
  scripture_reference: "Revelation 12:1"
})

Repo.insert!(%Mystery{
  name: "The Coronation of Mary",
  category: "glorious",
  order: 5,
  days_prayed: "Wednesdays, Thursdays, and Sundays",
  description: "Mary is crowned Queen of Heaven and Earth.",
  scripture_reference: "Revelation 12:1-6"
})

IO.puts("Seeded #{Repo.aggregate(Mystery, :count)} mysteries successfully!")
