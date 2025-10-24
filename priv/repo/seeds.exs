# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs                        # Add new data without wiping
#     RESET_DB=true mix run priv/repo/seeds.exs          # Wipe and start fresh
#
# In production:
#     FORCE_SEED=true mix run priv/repo/seeds.exs        # Add new data
#     FORCE_SEED=true RESET_DB=true mix run priv/repo/seeds.exs  # Wipe and start fresh

alias LumenViae.Repo
alias LumenViae.Rosary.{Mystery, Meditation, MeditationSet, MeditationSetMeditation}
import Ecto.Query

# ============================================================================
# Configuration
# ============================================================================

env = System.get_env("MIX_ENV") || "dev"
force_seed = System.get_env("FORCE_SEED") == "true"
reset_db = System.get_env("RESET_DB") == "true"

# Safety check: Prevent running in production unless explicitly allowed
if env == "prod" and not force_seed do
  IO.puts("""
  ⚠️  WARNING: Attempting to run seeds in production environment!

  To run seeds in production, set the FORCE_SEED environment variable:
    FORCE_SEED=true mix run priv/repo/seeds.exs           # Add new data without wiping
    FORCE_SEED=true RESET_DB=true mix run priv/repo/seeds.exs  # Wipe and start fresh

  Aborting...
  """)
  System.halt(1)
end

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  LUMEN VIAE - Database Seeding")
IO.puts(String.duplicate("=", 70))

# Optionally clear existing data
if reset_db do
  IO.puts("\n🔄 RESET_DB=true - Clearing existing data...")
  Repo.delete_all(MeditationSetMeditation)
  Repo.delete_all(MeditationSet)
  Repo.delete_all(Meditation)
  Repo.delete_all(Mystery)
  IO.puts("✓ Cleared existing data")
else
  IO.puts("\n➕ Adding new data (existing data will be preserved)")
end

# ============================================================================
# Helper Functions
# ============================================================================

insert_or_update_mystery = fn attrs ->
  case Repo.get_by(Mystery, name: attrs.name) do
    nil ->
      mystery = Repo.insert!(struct(Mystery, attrs))
      IO.puts("  ✓ Created: #{attrs.name}")
      mystery
    existing ->
      mystery = existing
      |> Mystery.changeset(attrs)
      |> Repo.update!()
      IO.puts("  ↻ Updated: #{attrs.name}")
      mystery
  end
end

# ============================================================================
# Seed Mysteries (The 15 Traditional Mysteries)
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 70))
IO.puts("Seeding Mysteries...")
IO.puts(String.duplicate("-", 70))

mysteries_data = [
  # Joyful Mysteries
  %{name: "The Annunciation", category: "joyful", order: 1,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "The angel Gabriel announces to Mary that she is to be the Mother of God.",
    scripture_reference: "Luke 1:26-38"},
  %{name: "The Visitation", category: "joyful", order: 2,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Mary visits her cousin Elizabeth, who proclaims her blessed among women.",
    scripture_reference: "Luke 1:39-56"},
  %{name: "The Nativity", category: "joyful", order: 3,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Jesus is born in Bethlehem and laid in a manger.",
    scripture_reference: "Luke 2:1-20"},
  %{name: "The Presentation", category: "joyful", order: 4,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Mary and Joseph present the infant Jesus in the Temple.",
    scripture_reference: "Luke 2:22-38"},
  %{name: "The Finding in the Temple", category: "joyful", order: 5,
    days_prayed: "Mondays, Thursdays, and Saturdays",
    description: "Jesus is found in the Temple, discussing with the doctors of the Law.",
    scripture_reference: "Luke 2:41-52"},

  # Sorrowful Mysteries
  %{name: "The Agony in the Garden", category: "sorrowful", order: 1,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus suffers greatly and sweats blood in the Garden of Gethsemane.",
    scripture_reference: "Matthew 26:36-46"},
  %{name: "The Scourging at the Pillar", category: "sorrowful", order: 2,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus is bound and cruelly scourged by the Roman soldiers.",
    scripture_reference: "Matthew 27:26"},
  %{name: "The Crowning with Thorns", category: "sorrowful", order: 3,
    days_prayed: "Tuesdays and Fridays",
    description: "A crown of thorns is pressed upon Jesus' sacred head.",
    scripture_reference: "Matthew 27:27-31"},
  %{name: "The Carrying of the Cross", category: "sorrowful", order: 4,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus carries His cross to Calvary, falling three times under its weight.",
    scripture_reference: "John 19:17"},
  %{name: "The Crucifixion", category: "sorrowful", order: 5,
    days_prayed: "Tuesdays and Fridays",
    description: "Jesus is nailed to the cross and dies for our salvation.",
    scripture_reference: "John 19:18-30"},

  # Glorious Mysteries
  %{name: "The Resurrection", category: "glorious", order: 1,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Jesus rises from the dead on the third day, glorious and immortal.",
    scripture_reference: "Matthew 28:1-10"},
  %{name: "The Ascension", category: "glorious", order: 2,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Jesus ascends into Heaven forty days after His Resurrection.",
    scripture_reference: "Acts 1:6-11"},
  %{name: "The Descent of the Holy Spirit", category: "glorious", order: 3,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "The Holy Spirit descends upon Mary and the Apostles at Pentecost.",
    scripture_reference: "Acts 2:1-4"},
  %{name: "The Assumption", category: "glorious", order: 4,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Mary is taken up body and soul into Heaven.",
    scripture_reference: "Revelation 12:1"},
  %{name: "The Coronation of Mary", category: "glorious", order: 5,
    days_prayed: "Wednesdays, Thursdays, and Sundays",
    description: "Mary is crowned Queen of Heaven and Earth.",
    scripture_reference: "Revelation 12:1-6"}
]

Enum.each(mysteries_data, insert_or_update_mystery)

IO.puts("\n✓ Mysteries seeded: #{Repo.aggregate(Mystery, :count)} total")

# ============================================================================
# Seed Meditations from External Files
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 70))
IO.puts("Seeding Meditations from Traditional Sources...")
IO.puts(String.duplicate("-", 70))

# Discover all meditation seed files in priv/repo/seeds/
seeds_dir = Path.join([:code.priv_dir(:lumen_viae), "repo", "seeds"])

if File.exists?(seeds_dir) do
  seeds_dir
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, "_meditations.exs"))
  |> Enum.sort()
  |> Enum.each(fn file ->
    file_path = Path.join(seeds_dir, file)
    IO.puts("\n📖 Loading: #{file}")
    Code.require_file(file_path)
  end)
else
  IO.puts("\n⚠️  Seeds directory not found: #{seeds_dir}")
end

IO.puts("\n✓ Meditations seeded: #{Repo.aggregate(Meditation, :count)} total")

# ============================================================================
# Create Meditation Sets
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 70))
IO.puts("Creating Meditation Sets...")
IO.puts(String.duplicate("-", 70))

# Get all meditations grouped by author and category
all_meditations = Meditation |> Repo.all() |> Repo.preload(:mystery)

meditations_by_source = all_meditations
|> Enum.group_by(& {&1.author, &1.mystery.category})

# Create sets for each unique combination
for {{author, category}, meditations} <- meditations_by_source do
  set_name = "#{String.capitalize(category)} Mysteries - #{author}"

  # Check if set already exists
  existing_set = Repo.get_by(MeditationSet, name: set_name)

  meditation_set = if existing_set do
    IO.puts("  ↻ Updating: #{set_name}")
    existing_set
  else
    set = Repo.insert!(%MeditationSet{
      name: set_name,
      category: category,
      description: "Meditations on the #{category} mysteries from #{author}"
    })
    IO.puts("  ✓ Created: #{set_name}")
    set
  end

  # Clear existing relationships for this set if updating
  if existing_set do
    from(m in MeditationSetMeditation, where: m.meditation_set_id == ^meditation_set.id)
    |> Repo.delete_all()
  end

  # Link meditations to set with proper order
  meditations
  |> Enum.sort_by(& &1.mystery.order)
  |> Enum.with_index(1)
  |> Enum.each(fn {meditation, order} ->
    Repo.insert!(%MeditationSetMeditation{
      meditation_set_id: meditation_set.id,
      meditation_id: meditation.id,
      order: order
    })
  end)
end

IO.puts("\n✓ Meditation sets created: #{Repo.aggregate(MeditationSet, :count)} total")

# ============================================================================
# Summary
# ============================================================================

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("  ✅ Database Seeding Completed Successfully!")
IO.puts(String.duplicate("=", 70))
IO.puts("\nFinal counts:")
IO.puts("  • Mysteries:         #{Repo.aggregate(Mystery, :count)}")
IO.puts("  • Meditations:       #{Repo.aggregate(Meditation, :count)}")
IO.puts("  • Meditation Sets:   #{Repo.aggregate(MeditationSet, :count)}")
IO.puts(String.duplicate("=", 70) <> "\n")
