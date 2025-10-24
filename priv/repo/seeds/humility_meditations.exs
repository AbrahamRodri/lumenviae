# Script to populate meditations on the virtue of Humility across all 15 mysteries
# Run with: mix run priv/repo/seeds/humility_meditations.exs

alias LumenViae.Repo
alias LumenViae.Rosary.{Mystery, Meditation}

meditations_data = [
  # Joyful Mysteries
  %{
    mystery_name: "The Annunciation",
    category: "joyful",
    content: """
    When the angel entered Mary's dwelling, he found her surrounded by the fragrance of silence. The Lord of all creation waited for the word of His creature, and Heaven stood still before her "Fiat." Humility became the throne of Omnipotence. Mary's lowliness was not ignorance of her grace, but clear vision of her nothingness beside Infinite Majesty. In her, self-love was extinguished, and divine light had free passage.

    So too must the soul bow low if God is to dwell within it. He will not descend into hearts filled with the noise of their own importance. The humble soul is a vessel empty enough to receive the ocean. When we say with Mary, "Be it done," we allow God to shape in us what we cannot fashion for ourselves. Thus humility is not weakness, but the silent might that lets God be all.
    """
  },
  %{
    mystery_name: "The Visitation",
    category: "joyful",
    content: """
    Grace in Mary could not remain still; humility always moves outward in love. She who bore God in secret did not look for praise, but for service. The road to Ain-Karim was steep, yet the humble do not measure the climb — they only see the need. In Elizabeth's home, Mary's greeting caused the unborn prophet to leap. Such is the power of humble charity: it awakens life where pride would bring only barrenness.

    When the soul visits another with God in its heart, Heaven moves unseen through simple words and gestures. Humility never boasts of its fruit, nor seeks the reward of recognition. It gives, and vanishes into the gift. In serving Elizabeth, Mary proclaimed her own nothingness — "He that is mighty hath done great things in me." To magnify God is the work of humility.
    """
  },
  %{
    mystery_name: "The Nativity",
    category: "joyful",
    content: """
    The cave of Bethlehem was the first pulpit of humility. The King of kings lay between beasts, wrapped not in glory but in rags. The world sought Him in palaces and found Him among the poor. Only hearts emptied of grandeur could recognize the Divine Child in the darkness. O soul, thou too must enter that stable; cast aside thy pride, and behold the God Who became small.

    Humility is not misery, but the radiant joy of knowing one's nothingness loved by Everything. The Virgin looked on the face of her newborn Son and saw the Infinite made dependent. Such is humility's wonder — that God stoops lower than we, to lift us higher than ourselves. The proud build towers and fall; the humble build cradles and God enters them.
    """
  },
  %{
    mystery_name: "The Presentation",
    category: "joyful",
    content: """
    Mary, though immaculate, came to the Temple to offer purification. The sinless obeyed the law of sinners, for humility hides its purity. She brought her Son to be redeemed, as though He were but another child of Israel — and yet He was the Redeemer. In that act, the humble Mother mirrored her Son's future Passion, offering the Eternal for the temporal.

    The soul that loves humility will give even what it most cherishes. It does not cling to its consolations but returns them to God with open hands. True humility never calls itself humble; it only seeks to conform to divine order. As Mary bowed before Simeon's prophecy, she accepted the sword as part of her gift. Every offering of love carries a hidden cross.
    """
  },
  %{
    mystery_name: "The Finding in the Temple",
    category: "joyful",
    content: """
    Mary sought her lost Child with tears, not reproaches. The humble do not question why God withdraws; they search for Him in faith and sorrow. For three days the Queen of Heaven felt the desolation that sinners feel when they lose grace — that spiritual poverty which no earthly treasure can heal. She tasted the pain of absence, so that she might console those who seek and do not find.

    When she found Him, she did not boast of her understanding, but accepted mystery with silence. Humility bows before divine wisdom, even when it wounds. To be found again by God is to realize that He was never truly gone — it was we who wandered. Thus the humble heart learns to trust the hidden ways of Love, and to rest quietly even when the light is veiled.
    """
  },

  # Sorrowful Mysteries
  %{
    mystery_name: "The Agony in the Garden",
    category: "sorrowful",
    content: """
    In Gethsemane, the Master knelt before the will of His Father, and the earth trembled at His submission. Humility descended to its lowest depth when God Himself said, "Not My will, but Thine be done." He who had command over legions chose obedience unto death. The proud spirit of Adam was crushed beneath the sweat of His blood.

    In the garden of prayer, humility drinks from the chalice that pride refuses. When the soul says its own "Fiat" beside Christ's, it learns the secret of strength through surrender. Humility does not flee the darkness; it holds the hand of God within it. The proud resist and break; the humble bend and conquer. Thus begins redemption — not on the Cross, but on the knees.
    """
  },
  %{
    mystery_name: "The Scourging at the Pillar",
    category: "sorrowful",
    content: """
    The Sinless One stood stripped before His creatures. Each lash was a hymn of humility. He who covered the lilies of the field was clothed in wounds. The world mocked the weakness of His flesh, not seeing that every blow exalted His love. The truly humble are always misunderstood; they accept dishonor as their portion.

    To meditate on His scourging is to see what pride deserves and humility redeems. The body of Christ became a mirror of our sins, yet He uttered no complaint. When we are humiliated unjustly, let us remember Him — silent beneath the whip, glorifying the Father even in shame. The proud defend themselves; the humble let God be their defense.
    """
  },
  %{
    mystery_name: "The Crowning with Thorns",
    category: "sorrowful",
    content: """
    The soldiers crowned Christ with thorns, thinking to mock His Kingship — yet that crown shone brighter than all gold. Humility accepts even derision and transforms it into majesty. The Head that bowed to wear thorns reigns eternally over angels. In humility's paradox, the insult becomes a diadem.

    Each thorn pierced the mind of Christ for our pride of thought. How eager we are to be esteemed, to be right, to be known! But the humble mind delights in being forgotten. When God wounds our vanity, it is mercy — He is shaping a crown for us after His own. Let us not flee the thorns; they are the blossoms of Heaven.
    """
  },
  %{
    mystery_name: "The Carrying of the Cross",
    category: "sorrowful",
    content: """
    Upon His shoulders lay the burden of all pride. Yet the weight of sin could not crush humility, for humility finds strength in acceptance. The world looked on a condemned man, but Heaven saw a Priest ascending His altar. Each fall upon the road was an act of love, not defeat.

    We too must carry our crosses in silence, not choosing them, but receiving them. Pride selects its sacrifices; humility embraces the one God sends. To follow Christ is to love the wood that wounds us, for there we learn His company. The humble soul walks behind the Man of Sorrows and finds joy hidden in pain.
    """
  },
  %{
    mystery_name: "The Crucifixion",
    category: "sorrowful",
    content: """
    Behold the summit of humility — God nailed between thieves. He who raised the dead now cannot move His hands; He who formed the worlds cannot draw His breath. Yet from this impotence bursts the cry of love: "Father, forgive them." The Cross is the pulpit from which humility preaches to eternity.

    When we suffer wrong, let us stand by that Cross and learn silence. Humility does not bargain with pain; it unites itself to the Crucified until love consumes complaint. The proud descend from their crosses to justify themselves; the humble remain and redeem. From that stillness flows the victory of saints.
    """
  },

  # Glorious Mysteries
  %{
    mystery_name: "The Resurrection",
    category: "glorious",
    content: """
    When Christ rose from the tomb, humility was vindicated. He did not appear first to the powerful, but to the penitent. His glory was hidden from kings and shown to a weeping woman. So it is with all divine triumph — humility alone can recognize it. Pride seeks proofs; faith meets the Risen One in silence.

    The soul that has died to self will rise with Him. True resurrection is not a shout but a still light within, where grace conquers the grave of pride. The humble are not astonished at the miracle, for they have already surrendered to its cause — the will of God. Their joy is not loud, but unending.
    """
  },
  %{
    mystery_name: "The Ascension",
    category: "glorious",
    content: """
    Humility does not cling even to the sweetest presence. Christ, having completed His work, ascended to the Father, teaching us that love must rise beyond sight. The Apostles gazed upward, longing to hold Him back, but the humble heart lets God go where He wills.

    When He ascended, He left no monument but the memory of His wounds. So too, the humble soul departs quietly, leaving behind only traces of mercy. To rise with Christ is to forget oneself entirely in God. Humility is not to fall low, but to rise unseen.
    """
  },
  %{
    mystery_name: "The Descent of the Holy Spirit",
    category: "glorious",
    content: """
    The Holy Spirit descended upon those who waited in prayer — not the learned, but the lowly. In that upper room, humility became fire. The tongues that had once fled in fear now spoke with divine boldness, for the humble are the fearless: they have nothing to lose, since they claim nothing as their own.

    Pride speaks many languages of self; humility speaks one — that of love. When the soul empties itself, the Spirit fills it. O Blessed Dove, descend also upon our littleness! Kindle within us that meek courage which conquers without violence and burns without consuming.
    """
  },
  %{
    mystery_name: "The Assumption",
    category: "glorious",
    content: """
    Humility cannot decay. The body that was God's dwelling knew no corruption, for Heaven owed it to Her who said, "Behold the handmaid." The Assumption is the flowering of hidden virtue — the fragrance of lowliness rising to its Source. Mary's glory is but her humility transfigured.

    So shall it be with the souls that live in quiet surrender. Their lowly deeds, unseen on earth, will shine in eternity. God gathers the small things last — because He keeps them closest. To be assumed is to be drawn upward by Love that remembers every act of humility done in secret.
    """
  },
  %{
    mystery_name: "The Coronation of Mary",
    category: "glorious",
    content: """
    The crown placed upon Mary's brow was wrought of all her hidden obediences. She reigns because she never sought to reign. Heaven calls her Queen, but she still calls herself Handmaid. Humility enthroned is no longer service forgotten, but service glorified.

    O soul, behold thy pattern! Pride seeks thrones on earth and loses them in death; humility kneels on earth and receives a crown in Heaven. If we would share Mary's glory, we must first share her self-forgetfulness. The last in their own eyes become first in the eyes of God.
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
        author: "Lumen Viae",
        source: "Meditations on Humility"
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
          author: "Lumen Viae",
          source: "Meditations on Humility",
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
