# Script to populate meditations from Bishop Fulton J. Sheen's reflections on the Rosary
# Run with: mix run priv/repo/seeds/fulton_sheen_meditations.exs

alias LumenViae.Repo
alias LumenViae.Rosary.{Mystery, Meditation}

meditations_data = [
  # Joyful Mysteries
  %{
    mystery_name: "The Annunciation",
    category: "joyful",
    content: """
    In the Annunciation, the birth of the Son of God in the flesh is made to hinge on the consent of a woman, as the fall of man in the garden of Paradise hinged on the consent of a man.

    God in His power might have assumed a human nature by force, as the hand of a man lays hold of a rose. But He willed not to invade His great gift of freedom without a creature's free response. Through the angel who salutes Mary in words that have become the first part of the Hail Mary, "Hail, full of grace, the Lord is with thee," Mary is asked if she will give God a man!

    Mary, learning that she will conceive without human love, but with the overshadowing of divine Love, consents, and a new humanity begins, with Mary as the new Eve, and Christ the new Adam.

    The Annunciation is the Mystery of the joy of freedom. Our free will is the only thing in the world that is our own. God can take away anything else—our health, wealth, power—but God will never force us to love Him or to obey Him. The charm of Yes lies in the possibility that one might have said No.

    Mary has taught us to say *Fiat* to God. "Be it done to me according to Thy word." But God Himself has taught us that, since He would not invade the freedom of a woman, then a man should never do so.
    """
  },
  %{
    mystery_name: "The Visitation",
    category: "joyful",
    content: """
    "In the days that followed, Mary rose up and went with all haste to a city of Judea, in the hill country, where Zachary dwelt; and there entering in she gave Elizabeth greeting. No sooner had Elizabeth heard Mary's greeting, than the child leaped in her womb; and Elizabeth herself was filled with the Holy Ghost; so that she cried out with a loud voice, 'Blessed art thou among women, and blessed is the fruit of thy womb.'"

    The first miracle worked by our Lord on earth was performed while He was still in His Mother's womb. He stirred the unborn John and brought consciousness of His presence to Elizabeth, the cousin of His Mother. Thus, long before Cana, our Lord shows that it is through His Mother that He works His unseen wonders in the heart and through her that He is brought into the souls of men.

    The joy of this Mystery is that of the Old Testament meeting the New, and of the young maiden greeting the old woman, as Mary bursts into the most revolutionary song that was ever sung, the *Magnificat*, foretelling the day when the mighty would be unseated from their thrones, and the poor would be exalted.

    Yet at that moment, when Elizabeth is the first to call her the Mother of God, even before our Lord is born, Mary answers that her greatness is due to Him, and that she was chosen because she was lowly.
    """
  },
  %{
    mystery_name: "The Nativity",
    category: "joyful",
    content: """
    Love tends to become like that which it loves. God loved man; therefore, He became man.

    Thanks to His human nature, He could take on our woes and our sorrows, and feel the effects of sin as if they were His very own. But all this was conditioned upon Mary's giving Him a human nature. Without her He would never have had eyes to see the multitude hungry in the desert, or ears to hear the pleading of the lame man of Jericho, or hands to caress children, or feet to seek the lost sheep.

    For nine months, her own body was the natural Eucharist, in which God shared communion with human life, thus preparing for that greater Eucharist, when human life would commune with the Divine.

    Mary's joy was to form Christ in her own body; her joy now is to form Christ in our souls.
    """
  },
  %{
    mystery_name: "The Presentation",
    category: "joyful",
    content: """
    Every child is an arrow shot out of the bow of its mother, but its target is God. Children have come through mothers, but they do not belong to them.

    Mary acknowledges this claim of divinity on her Child by presenting Him back again to God, as she offers the temple of His Body in the temple made by hands.

    Mary here anticipated the joy of every mother who brings her child to the baptismal font, where God may claim His own. But in the case of Mary, the Child was claimed for sacrifice, as the aged Simeon said that He was a sign to be contradicted, for the Cross is the contradiction.

    Mary was even told that a sword her own soul would pierce. That would happen when her Son on the Cross would have His heart pierced with a lance.
    """
  },
  %{
    mystery_name: "The Finding in the Temple",
    category: "joyful",
    content: """
    There are two kinds of souls in the world: those who hide from God and those from whom God hides. But when God hides, He hides in order that He might be sought the more, as if to draw out a deeper love.

    During the three days when the Divine Child was lost, the Blessed Mother became the mother of sinners. The essence of sin is the loss of God, and Mary lost God, not spiritually, but physically.

    During those three days, she came to know something of the solitariness of the sinner, the loneliness of the guilty, and the aloneness of the frustrated.

    Her Divine Son, twenty-one years later, would feel it for Himself on the Cross when He would ask why God had abandoned Him.

    Let no sinner ever despair of Divine mercy, because Mary understands the tortures of the heart, but above all, because she knows where to find Christ.
    """
  },

  # Sorrowful Mysteries
  %{
    mystery_name: "The Agony in the Garden",
    category: "sorrowful",
    content: """
    A kind person in the face of pain seeks to relieve the sufferings of his friend; so does moral kindness in the face of evil take on the punishment which evil deserves.

    Our Lord, though guilty of no sin, permitted Himself to feel the inner effects of sin: sadness, fear, and a sense of loneliness.

    He permits His head to feel blasphemies as if His lips had pronounced them; His hands to feel the sins of theft as if He had stolen.

    Sin is in the blood. If sin is in the blood, to atone for it, blood must be poured out. Our Lord never intended that any other blood than His own should be shed in expiation for sins.

    "The spirit is willing, but the flesh is weak." Evil has its hour—but God has His day.
    """
  },
  %{
    mystery_name: "The Scourging at the Pillar",
    category: "sorrowful",
    content: """
    Omnipotence is bound to a pillar in the hour of His death, as He was bound in swaddling clothes in the hour of His birth.

    The scourging is an act of reparation for the excessive cult of the body. "The body is for the Lord."

    In expiation for self-indulgence, His body, as the second Ark of the Covenant, is disclosed to profane eyes.

    We are saved by other stars and stripes than those on the flag—by the stars and stripes of Christ: by His stars we are illumined, by His stripes we are healed.
    """
  },
  %{
    mystery_name: "The Crowning with Thorns",
    category: "sorrowful",
    content: """
    If the scourging was reparation for the sins of the flesh, then the crowning with thorns was the atonement for the sins of the mind—for the atheists who wish there were no God, for the doubters whose evil lives becloud their thinking, for the egotists, centered on themselves.

    Into His hands they placed a reed, the symbol of His kingdom presumed to be false and unstable like the reed.

    He who expects to preserve his faith without being mocked by the world is either weak in it, or else not so bold in goodness as to draw upon himself the mocking insults of another purple robe and a torturing circle of thorns.
    """
  },
  %{
    mystery_name: "The Carrying of the Cross",
    category: "sorrowful",
    content: """
    Any cross would be easy to bear if we could only tailor it to fit ourselves.

    Our Lord's Cross was not made by Him, but for Him.

    Crosses are of two kinds: pure ones, which come from the outside—pain, persecution, ridicule; and impure ones, which come from our sins—sadness, despair, unhappiness.

    Our Lord never promised that we would be without a cross; He only promised that we would never be overcome by one.

    He who carries his cross daily in union with Christ makes it redemptive. The whole Cross borne in union with His will is easier to bear than the splinters against which we rebel.
    """
  },
  %{
    mystery_name: "The Crucifixion",
    category: "sorrowful",
    content: """
    Our Lord spent thirty years obeying, three years teaching, three hours redeeming.

    He redeemed as a gold chalice thrown into fire is purified and recast for holy use.

    The Cross reveals that unless there is a Good Friday in our lives, there will never be an Easter Sunday.

    Unless there is the crown of thorns, there will never be the halo of light.

    Unless there is the scourged body, there will never be a glorified one.

    It is human to come down from the Cross—it is divine to hang there.
    """
  },

  # Glorious Mysteries
  %{
    mystery_name: "The Resurrection",
    category: "glorious",
    content: """
    He who was born once in Bethlehem is now born again in glory.

    Our Lord rises by the power of God, giving the earth the only serious wound it ever received—the irreparable wound of an empty grave.

    The Resurrection begins to affect our lives the day of Baptism. When baptized, we are plunged into the waters as if buried in the sepulcher to sin and death, emerging clothed with grace as Christ from the tomb.

    The empty tomb is the pledge of our own.
    """
  },
  %{
    mystery_name: "The Ascension",
    category: "glorious",
    content: """
    For forty days after His Resurrection, He spoke to His Apostles of the Kingdom of God.

    Then, blessing them, He was taken up to Heaven, there to intercede eternally for us.

    The Ascension is the assurance of our own glory after judgment.

    "He that ascended is the same that descended."

    He ascended that we might seek the things that are above.
    """
  },
  %{
    mystery_name: "The Descent of the Holy Spirit",
    category: "glorious",
    content: """
    If our Lord had remained on earth, He would have been only a symbol to be copied, not a life to be lived.

    By ascending, He sent His Spirit that men might live His life in His Mystical Body.

    The Spirit came as a mighty wind and tongues of fire, making the Apostles one with Christ, as the soul makes one body of its members.

    The Church is the Body of Christ, vivified by His Spirit, governed by His Head, and sanctified by His grace.
    """
  },
  %{
    mystery_name: "The Assumption",
    category: "glorious",
    content: """
    What the Ascension was to our Lord, the Assumption is to His Mother.

    The flesh that once gave God His human life is now glorified in Heaven.

    If husband and wife in marriage are made two in one flesh, shall not the new Adam and the new Eve be two in one spirit?

    Mary's Assumption is the pledge of the resurrection of the body for all who are Christ's.
    """
  },
  %{
    mystery_name: "The Coronation of Mary",
    category: "glorious",
    content: """
    As Christ ascended to His throne of glory, so Mary was crowned Queen of Heaven and earth.

    Her Divine Son placed on her brow the crown that His thorns had won.

    He who made her His Mother in Bethlehem now makes her His Bride in eternity.

    As our first mother brought us forth to sin, so our heavenly Mother brings us forth to grace.

    In Heaven she reigns, not apart from us but for us.
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
        author: "Bishop Fulton J. Sheen",
        source: "The World's First Love"
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
          author: "Bishop Fulton J. Sheen",
          source: "The World's First Love",
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
