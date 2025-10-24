# Script to populate meditations from "Glories of Mary" by St. Alphonsus Liguori
# Run with: mix run priv/repo/seeds/glories_of_mary_meditations.exs

alias LumenViae.Repo
alias LumenViae.Rosary.{Mystery, Meditation}

meditations_data = [
  # Joyful Mysteries
  %{
    mystery_name: "The Annunciation",
    category: "joyful",
    content: """
    Let us contemplate in this mystery how the angel Gabriel saluted our Blessed Lady with the title *Full of grace,* and declared unto her the Incarnation of Our Lord and Saviour Jesus Christ.

    O Holy Mary, Queen of virgins, by the most high mystery of the Incarnation of thy beloved Son, obtain of the Lord, through thy intercession, humility of heart and perfect purity of mind and body. Amen.
    """
  },
  %{
    mystery_name: "The Visitation",
    category: "joyful",
    content: """
    Let us contemplate in this mystery how the Blessed Virgin Mary, understanding from the angel that her cousin St. Elizabeth had conceived, went with haste into the mountain country of Judea to visit her, and remained with her three months.

    O most pure Virgin, by that charity which moved thee to visit thy cousin St. Elizabeth, obtain of thy beloved Son that we may be preserved from all sin, and may by works of charity be made worthy to obtain mercy in the day of judgment. Amen.
    """
  },
  %{
    mystery_name: "The Nativity",
    category: "joyful",
    content: """
    Let us contemplate in this mystery how the Blessed Virgin Mary, when the time of her delivery was come, brought forth our Redeemer Jesus Christ at midnight, and laid him in a manger, because there was no room for him in the inn at Bethlehem.

    O most pure Mother of God, through thy virginal and most joyful delivery, we beseech thee obtain for us peace and goodwill toward men; and by that joy which thy heart felt at the birth of thy Son, may we never lose the fruit of his passion. Amen.
    """
  },
  %{
    mystery_name: "The Presentation",
    category: "joyful",
    content: """
    Let us contemplate in this mystery how the Blessed Virgin, on the day of her purification, presented the child Jesus in the Temple, where holy Simeon, giving thanks to God, with great devotion received him into his arms.

    O Holy Virgin, by thy humility in offering Jesus in the Temple, and by the hands of Simeon, with the offering of the poor, obtain for us grace to offer up ourselves to God in a spirit of humility and devotion. Amen.
    """
  },
  %{
    mystery_name: "The Finding in the Temple",
    category: "joyful",
    content: """
    Let us contemplate in this mystery how the Blessed Virgin, having lost her beloved Son in Jerusalem, sought him for three days, and at length found him in the Temple sitting in the midst of the doctors, hearing them and asking them questions.

    O most Blessed Mother, through the anxieties of thy three days' loss of thy Son, obtain for us grace never to lose him by mortal sin, but to find him again by true repentance, should we have the misfortune to lose him. Amen.
    """
  },

  # Sorrowful Mysteries
  %{
    mystery_name: "The Agony in the Garden",
    category: "sorrowful",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ was so sad in the Garden of Olives that his sweat became as drops of blood trickling down to the ground.

    O most afflicted Virgin, Queen of martyrs, by the anguish which thy Son suffered in the Garden, obtain for us grace to resign ourselves to the will of God in all our afflictions, and to mortify our passions and desires, so that we may be always pleasing to him. Amen.
    """
  },
  %{
    mystery_name: "The Scourging at the Pillar",
    category: "sorrowful",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ was most cruelly scourged in Pilate's house, the number of stripes being about five thousand.

    O Mother of God, overflowing fountain of patience, through those stripes which thy only and much-beloved Son vouchsafed to suffer for us, obtain of him for us grace to mortify our rebellious senses, to avoid occasions of sin, and to be ready to suffer everything rather than offend God. Amen.
    """
  },
  %{
    mystery_name: "The Crowning with Thorns",
    category: "sorrowful",
    content: """
    Let us contemplate in this mystery how the cruel ministers of Satan platted a crown of sharp thorns and cruelly pressed it on the sacred head of Our Lord Jesus Christ.

    O Mother of our eternal Prince, the King of glory, by those sharp thorns wherewith his sacred head was pierced, obtain for us that we may be delivered from all notions of pride, and escape the shame which our sins deserve at the day of judgment. Amen.
    """
  },
  %{
    mystery_name: "The Carrying of the Cross",
    category: "sorrowful",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ, being sentenced to die, bore with the most amazing patience the cross which was laid upon him for his greater torment and ignominy.

    O holy Virgin, example of patience, by the most painful carrying of the cross in which thy Son, Our Lord Jesus Christ, bore the heavy weight of our sins, obtain for us through thy intercession courage and strength to follow his steps and bear our cross after him to the end of our lives. Amen.
    """
  },
  %{
    mystery_name: "The Crucifixion",
    category: "sorrowful",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ, being come to Mount Calvary, was stripped of his clothes and his hands and feet nailed to the cross in the presence of his most afflicted Mother.

    O holy Mary, Mother of God, as the body of thy beloved Son was for us stretched upon the cross, so may we offer up our souls and bodies to be crucified with him, and our hearts to be pierced with grief at his most bitter Passion; and thou, O most sorrowful Mother, graciously vouchsafe to help us by thy powerful intercession to accomplish the work of our salvation. Amen.
    """
  },

  # Glorious Mysteries
  %{
    mystery_name: "The Resurrection",
    category: "glorious",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ, triumphing gloriously over death, rose again the third day immortal and incorruptible.

    O glorious Virgin Mary, by that unspeakable joy thou receivedst in the resurrection of thy beloved Son, obtain for us the grace to rise spiritually from the death of sin to the life of grace. Amen.
    """
  },
  %{
    mystery_name: "The Ascension",
    category: "glorious",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ, forty days after his resurrection, ascended into heaven in the presence of his most holy Mother and his disciples, to take possession of his kingdom and prepare a place for us.

    O Mother of God, through thy beloved Son's triumphant ascension into heaven, obtain for us such a lively faith that our hearts may always be fixed there where our true treasure is. Amen.
    """
  },
  %{
    mystery_name: "The Descent of the Holy Spirit",
    category: "glorious",
    content: """
    Let us contemplate in this mystery how Our Lord Jesus Christ, being seated in heaven at the right hand of God the Father, sent as he had promised the Holy Ghost upon his Apostles, who, after he was ascended, returned to Jerusalem, and continued in prayer and supplication with the Blessed Virgin Mary, expecting the fulfilling of his promise.

    O sacred Virgin, spouse of the Holy Ghost, obtain for us by thy intercession that the same Spirit may come into our souls and make them temples of his glory. Amen.
    """
  },
  %{
    mystery_name: "The Assumption",
    category: "glorious",
    content: """
    Let us contemplate in this mystery how the glorious Virgin, many years after the resurrection of her Son, passed out of this world unto him and was by him received into heaven, accompanied by the holy angels.

    O most pure Virgin, through thy happy Assumption into heaven, obtain of thy beloved Son for us that our hearts may be detached from earthly things, and that we may ever long to be united with him in heaven. Amen.
    """
  },
  %{
    mystery_name: "The Coronation of Mary",
    category: "glorious",
    content: """
    Let us contemplate in this mystery how the glorious Virgin Mary was crowned by her divine Son Queen of Heaven and earth, and made advocate of sinners.

    O glorious Queen of Heaven, by the grace of thy glorious Coronation, obtain for us a perseverance in grace, and a crown of glory hereafter to rejoice with thee forever in heaven. Amen.
    """
  }
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
      # Check if meditation already exists for this mystery, author, and source
      existing = Repo.get_by(Meditation,
        mystery_id: mystery.id,
        author: "St. Alphonsus Liguori",
        source: "Glories of Mary"
      )

      if existing do
        # Update existing meditation if content changed
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
        # Insert new meditation
        Repo.insert!(%Meditation{
          content: String.trim(data.content),
          author: "St. Alphonsus Liguori",
          source: "Glories of Mary",
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
