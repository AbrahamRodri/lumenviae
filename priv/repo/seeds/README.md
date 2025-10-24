# Database Seeds

This directory contains seed files for populating the Lumen Viae database with meditation content.

## How Seeding Works

The seed system is **idempotent** - you can run it multiple times safely without creating duplicates. It will:
- Create new data that doesn't exist
- Update existing data if content has changed
- Skip data that already exists and hasn't changed

## Usage

### Development

**Add new data (preserves existing data):**
```bash
mix run priv/repo/seeds.exs
```

**Wipe and start fresh:**
```bash
RESET_DB=true mix run priv/repo/seeds.exs
```

### Production

**Add new data (preserves existing data):**
```bash
FORCE_SEED=true mix run priv/repo/seeds.exs
```

**Wipe and start fresh:**
```bash
FORCE_SEED=true RESET_DB=true mix run priv/repo/seeds.exs
```

## Adding New Meditations

1. Create a new seed file in this directory following the naming pattern: `{author}_meditations.exs`

2. Use the template structure:

```elixir
# priv/repo/seeds/new_author_meditations.exs
alias LumenViae.Repo
alias LumenViae.Rosary.{Mystery, Meditation}

meditations_data = [
  %{
    mystery_name: "The Annunciation",
    category: "joyful",
    content: """
    Your meditation content here...
    """
  },
  # ... more meditations
]

# Get all mysteries
mysteries =
  Mystery
  |> Repo.all()
  |> Enum.group_by(& &1.name)

# Insert or update meditations
{inserted, updated, skipped} =
  Enum.reduce(meditations_data, {0, 0, 0}, fn data, {ins, upd, skip} ->
    mystery = Map.get(mysteries, data.mystery_name) |> List.first()

    if mystery do
      existing = Repo.get_by(Meditation,
        mystery_id: mystery.id,
        author: "Your Author Name",
        source: "Your Source"
      )

      if existing do
        if existing.content != String.trim(data.content) do
          existing
          |> Meditation.changeset(%{content: String.trim(data.content)})
          |> Repo.update!()
          IO.puts("  ↻ Updated: #{data.mystery_name}")
          {ins, upd + 1, skip}
        else
          IO.puts("  ─ Skipped: #{data.mystery_name} (no changes)")
          {ins, upd, skip + 1}
        end
      else
        Repo.insert!(%Meditation{
          content: String.trim(data.content),
          author: "Your Author Name",
          source: "Your Source",
          mystery_id: mystery.id
        })
        IO.puts("  ✓ Created: #{data.mystery_name}")
        {ins + 1, upd, skip}
      end
    else
      IO.puts("  ✗ Mystery not found: #{data.mystery_name}")
      {ins, upd, skip}
    end
  end)

IO.puts("\n  Summary: #{inserted} created, #{updated} updated, #{skipped} skipped")
```

3. Run seeds to add the new meditations:
```bash
mix run priv/repo/seeds.exs
```

The main seed script will automatically discover and run all `*_meditations.exs` files in this directory.

## Current Meditation Sources

- `glories_of_mary_meditations.exs` - Meditations from St. Alphonsus Liguori's "Glories of Mary"
- `fulton_sheen_meditations.exs` - Meditations from Bishop Fulton J. Sheen's "The World's First Love"

## How Meditation Sets Are Created

Meditation sets are automatically created based on the meditations in the database:
- Sets are grouped by **author** and **category** (joyful, sorrowful, glorious)
- Each set contains 5 meditations (one per mystery in that category)
- Sets are named: `{Category} Mysteries - {Author}`

For example:
- "Joyful Mysteries - St. Alphonsus Liguori"
- "Sorrowful Mysteries - Bishop Fulton J. Sheen"

## Safety Features

- **Production Protection**: Seeds won't run in production without `FORCE_SEED=true`
- **No Duplicates**: Running seeds multiple times won't create duplicate data
- **Smart Updates**: Content is only updated when it actually changes
- **Auto-Discovery**: New meditation files are automatically found and loaded
