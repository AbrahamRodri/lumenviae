defmodule LumenViae.Repo.Migrations.FillMysteryFruitsAndKeyVerses do
  use Ecto.Migration

  # The fruit and the key verse of each of the 27 mysteries, copied from
  # the iOS app (MysteryData.traditionalFruits and
  # MysteriesInScriptureData.keyVerses, the verse split from its citation
  # on " — " as the app splits it), so the server serves what the app
  # shows.
  #
  # Literal strings and raw SQL, so this never depends on today's modules.
  # Rows are matched on category and order, never on id (the app's ids
  # and production's differ) or name, and a value is written only where
  # the column is still empty, so a value set in the console is never
  # overwritten and running it twice changes nothing. A row outside the 27
  # is never touched. updated_at moves with each row filled, so the Rosary
  # content's date moves with it. No PaperTrail version rows are written
  # (raw SQL bypasses the resource), as with the days_prayed correction.
  def up do
    execute """
    UPDATE mysteries SET fruit = 'Humility', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 1 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Behold thou shalt conceive in thy womb, and shalt bring forth a son; and thou shalt call his name Jesus.',
        key_verse_reference = 'Luke 1:31',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 1
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Love of Neighbor', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 2 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Blessed art thou among women, and blessed is the fruit of thy womb.',
        key_verse_reference = 'Luke 1:42',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 2
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Poverty of Spirit', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 3 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And she brought forth her firstborn son, and wrapped him up in swaddling clothes, and laid him in a manger.',
        key_verse_reference = 'Luke 2:7',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 3
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Obedience', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 4 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Now thou dost dismiss thy servant, O Lord, according to thy word in peace; because my eyes have seen thy salvation.',
        key_verse_reference = 'Luke 2:29-30',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 4
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Joy in Finding Jesus', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 5 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Did you not know, that I must be about my father''s business?',
        key_verse_reference = 'Luke 2:49',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'joyful' AND "order" = 5
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Sorrow for Sin', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 1 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'My Father, if it be possible, let this chalice pass from me. Nevertheless not as I will, but as thou wilt.',
        key_verse_reference = 'Matthew 26:39',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 1
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Purity', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 2 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Then therefore, Pilate took Jesus, and scourged him.',
        key_verse_reference = 'John 19:1',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 2
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Moral Courage', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 3 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And platting a crown of thorns, they put it upon his head.',
        key_verse_reference = 'Matthew 27:29',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 3
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Patience', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 4 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And bearing his own cross, he went forth to that place which is called Calvary.',
        key_verse_reference = 'John 19:17',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 4
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Perseverance', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 5 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Father, into thy hands I commend my spirit.',
        key_verse_reference = 'Luke 23:46',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'sorrowful' AND "order" = 5
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Faith', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 1 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'He is not here, for he is risen, as he said.',
        key_verse_reference = 'Matthew 28:6',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 1
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Hope', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 2 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And the Lord Jesus, after he had spoken to them, was taken up into heaven, and sitteth on the right hand of God.',
        key_verse_reference = 'Mark 16:19',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 2
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Love of God', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 3 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And they were all filled with the Holy Ghost, and they began to speak with divers tongues.',
        key_verse_reference = 'Acts 2:4',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 3
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Grace of a Happy Death', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 4 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'He that is mighty hath done great things to me; and holy is his name.',
        key_verse_reference = 'Luke 1:49',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 4
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Trust in Mary''s Intercession', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 5 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And a great sign appeared in heaven: A woman clothed with the sun, and the moon under her feet, and on her head a crown of twelve stars.',
        key_verse_reference = 'Apocalypse 12:1',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'glorious' AND "order" = 5
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Openness to the Holy Spirit', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 1 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'This is my beloved Son, in whom I am well pleased.',
        key_verse_reference = 'Matthew 3:17',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 1
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'To Jesus through Mary', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 2 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Whatsoever he shall say to you, do ye.',
        key_verse_reference = 'John 2:5',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 2
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Repentance and Trust in God', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 3 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'The time is accomplished, and the kingdom of God is at hand: repent, and believe the gospel.',
        key_verse_reference = 'Mark 1:15',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 3
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Desire for Holiness', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 4 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And he was transfigured before them. And his face did shine as the sun.',
        key_verse_reference = 'Matthew 17:2',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 4
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Eucharistic Adoration', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 5 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Take ye, and eat. This is my body.',
        key_verse_reference = 'Matthew 26:26',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'luminous' AND "order" = 5
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Surrender to God''s Will', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 1 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And thy own soul a sword shall pierce, that, out of many hearts, thoughts may be revealed.',
        key_verse_reference = 'Luke 2:35',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 1
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Trust in God''s Providence', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 2 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Arise, and take the child and his mother, and fly into Egypt.',
        key_verse_reference = 'Matthew 2:13',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 2
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Seeking Jesus Above All', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 3 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Son, why hast thou done so to us? behold thy father and I have sought thee sorrowing.',
        key_verse_reference = 'Luke 2:48',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 3
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Compassion for Christ', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 4 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'And there followed him a great multitude of people, and of women, who bewailed and lamented him.',
        key_verse_reference = 'Luke 23:27',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 4
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Standing Faithful at the Cross', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 5 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Now there stood by the cross of Jesus, his mother.',
        key_verse_reference = 'John 19:25',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 5
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Receiving Christ into Our Hearts', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 6 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Joseph of Arimathea... came and took away the body of Jesus.',
        key_verse_reference = 'John 19:38',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 6
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """

    execute """
    UPDATE mysteries SET fruit = 'Hope in the Resurrection', updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 7 AND (fruit IS NULL OR fruit = '')
    """

    execute """
    UPDATE mysteries
    SET key_verse = 'Now there was in the place where he was crucified, a garden; and in the garden a new sepulchre... There, therefore, they laid Jesus.',
        key_verse_reference = 'John 19:41-42',
        updated_at = date_trunc('second', timezone('UTC', now()))
    WHERE category = 'seven_sorrows' AND "order" = 7
      AND (key_verse IS NULL OR key_verse = '')
      AND (key_verse_reference IS NULL OR key_verse_reference = '')
    """
  end

  # Empties only values still exactly as this migration wrote them.
  def down do
    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'joyful' AND "order" = 1 AND fruit = 'Humility'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'joyful' AND "order" = 1 AND key_verse = 'Behold thou shalt conceive in thy womb, and shalt bring forth a son; and thou shalt call his name Jesus.' AND key_verse_reference = 'Luke 1:31'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'joyful' AND "order" = 2 AND fruit = 'Love of Neighbor'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'joyful' AND "order" = 2 AND key_verse = 'Blessed art thou among women, and blessed is the fruit of thy womb.' AND key_verse_reference = 'Luke 1:42'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'joyful' AND "order" = 3 AND fruit = 'Poverty of Spirit'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'joyful' AND "order" = 3 AND key_verse = 'And she brought forth her firstborn son, and wrapped him up in swaddling clothes, and laid him in a manger.' AND key_verse_reference = 'Luke 2:7'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'joyful' AND "order" = 4 AND fruit = 'Obedience'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'joyful' AND "order" = 4 AND key_verse = 'Now thou dost dismiss thy servant, O Lord, according to thy word in peace; because my eyes have seen thy salvation.' AND key_verse_reference = 'Luke 2:29-30'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'joyful' AND "order" = 5 AND fruit = 'Joy in Finding Jesus'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'joyful' AND "order" = 5 AND key_verse = 'Did you not know, that I must be about my father''s business?' AND key_verse_reference = 'Luke 2:49'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'sorrowful' AND "order" = 1 AND fruit = 'Sorrow for Sin'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'sorrowful' AND "order" = 1 AND key_verse = 'My Father, if it be possible, let this chalice pass from me. Nevertheless not as I will, but as thou wilt.' AND key_verse_reference = 'Matthew 26:39'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'sorrowful' AND "order" = 2 AND fruit = 'Purity'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'sorrowful' AND "order" = 2 AND key_verse = 'Then therefore, Pilate took Jesus, and scourged him.' AND key_verse_reference = 'John 19:1'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'sorrowful' AND "order" = 3 AND fruit = 'Moral Courage'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'sorrowful' AND "order" = 3 AND key_verse = 'And platting a crown of thorns, they put it upon his head.' AND key_verse_reference = 'Matthew 27:29'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'sorrowful' AND "order" = 4 AND fruit = 'Patience'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'sorrowful' AND "order" = 4 AND key_verse = 'And bearing his own cross, he went forth to that place which is called Calvary.' AND key_verse_reference = 'John 19:17'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'sorrowful' AND "order" = 5 AND fruit = 'Perseverance'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'sorrowful' AND "order" = 5 AND key_verse = 'Father, into thy hands I commend my spirit.' AND key_verse_reference = 'Luke 23:46'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'glorious' AND "order" = 1 AND fruit = 'Faith'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'glorious' AND "order" = 1 AND key_verse = 'He is not here, for he is risen, as he said.' AND key_verse_reference = 'Matthew 28:6'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'glorious' AND "order" = 2 AND fruit = 'Hope'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'glorious' AND "order" = 2 AND key_verse = 'And the Lord Jesus, after he had spoken to them, was taken up into heaven, and sitteth on the right hand of God.' AND key_verse_reference = 'Mark 16:19'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'glorious' AND "order" = 3 AND fruit = 'Love of God'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'glorious' AND "order" = 3 AND key_verse = 'And they were all filled with the Holy Ghost, and they began to speak with divers tongues.' AND key_verse_reference = 'Acts 2:4'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'glorious' AND "order" = 4 AND fruit = 'Grace of a Happy Death'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'glorious' AND "order" = 4 AND key_verse = 'He that is mighty hath done great things to me; and holy is his name.' AND key_verse_reference = 'Luke 1:49'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'glorious' AND "order" = 5 AND fruit = 'Trust in Mary''s Intercession'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'glorious' AND "order" = 5 AND key_verse = 'And a great sign appeared in heaven: A woman clothed with the sun, and the moon under her feet, and on her head a crown of twelve stars.' AND key_verse_reference = 'Apocalypse 12:1'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'luminous' AND "order" = 1 AND fruit = 'Openness to the Holy Spirit'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'luminous' AND "order" = 1 AND key_verse = 'This is my beloved Son, in whom I am well pleased.' AND key_verse_reference = 'Matthew 3:17'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'luminous' AND "order" = 2 AND fruit = 'To Jesus through Mary'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'luminous' AND "order" = 2 AND key_verse = 'Whatsoever he shall say to you, do ye.' AND key_verse_reference = 'John 2:5'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'luminous' AND "order" = 3 AND fruit = 'Repentance and Trust in God'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'luminous' AND "order" = 3 AND key_verse = 'The time is accomplished, and the kingdom of God is at hand: repent, and believe the gospel.' AND key_verse_reference = 'Mark 1:15'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'luminous' AND "order" = 4 AND fruit = 'Desire for Holiness'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'luminous' AND "order" = 4 AND key_verse = 'And he was transfigured before them. And his face did shine as the sun.' AND key_verse_reference = 'Matthew 17:2'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'luminous' AND "order" = 5 AND fruit = 'Eucharistic Adoration'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'luminous' AND "order" = 5 AND key_verse = 'Take ye, and eat. This is my body.' AND key_verse_reference = 'Matthew 26:26'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 1 AND fruit = 'Surrender to God''s Will'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 1 AND key_verse = 'And thy own soul a sword shall pierce, that, out of many hearts, thoughts may be revealed.' AND key_verse_reference = 'Luke 2:35'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 2 AND fruit = 'Trust in God''s Providence'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 2 AND key_verse = 'Arise, and take the child and his mother, and fly into Egypt.' AND key_verse_reference = 'Matthew 2:13'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 3 AND fruit = 'Seeking Jesus Above All'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 3 AND key_verse = 'Son, why hast thou done so to us? behold thy father and I have sought thee sorrowing.' AND key_verse_reference = 'Luke 2:48'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 4 AND fruit = 'Compassion for Christ'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 4 AND key_verse = 'And there followed him a great multitude of people, and of women, who bewailed and lamented him.' AND key_verse_reference = 'Luke 23:27'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 5 AND fruit = 'Standing Faithful at the Cross'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 5 AND key_verse = 'Now there stood by the cross of Jesus, his mother.' AND key_verse_reference = 'John 19:25'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 6 AND fruit = 'Receiving Christ into Our Hearts'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 6 AND key_verse = 'Joseph of Arimathea... came and took away the body of Jesus.' AND key_verse_reference = 'John 19:38'
    """

    execute """
    UPDATE mysteries SET fruit = NULL
    WHERE category = 'seven_sorrows' AND "order" = 7 AND fruit = 'Hope in the Resurrection'
    """

    execute """
    UPDATE mysteries SET key_verse = NULL, key_verse_reference = NULL
    WHERE category = 'seven_sorrows' AND "order" = 7 AND key_verse = 'Now there was in the place where he was crucified, a garden; and in the garden a new sepulchre... There, therefore, they laid Jesus.' AND key_verse_reference = 'John 19:41-42'
    """
  end
end
