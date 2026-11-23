defmodule LumenViae.Repo.Migrations.CreditSetPortraits do
  use Ecto.Migration

  # Three set portraits are public but carry no artist or source: Blessed
  # Anne Catherine Emmerich's (sets 42, 45, 46, 53), St Ignatius's (48) and
  # Fr Faber's (59, 65). product-research identified each at the source
  # (reports/rig/copyright-review/inventory.md, "Item 17"); Abraham's rule
  # is to credit the real artist and source. Liguori's and Agreda's are not
  # credited here: neither is safely identified, and replacing them is a
  # picture change for Abraham.
  #
  # A portrait sits on the author and, for a set that has its own upload,
  # on the set. Both are filled, and only where the picture is the one
  # identified: those sets, and the authors they link to, with an uploaded
  # image of that exact size and no artist yet. (A set's own author
  # column may be blank, its byline derived from its meditations, so it is not
  # used to find them.) Anywhere else (a test database, or a portrait
  # changed since) nothing matches and nothing changes.
  #
  # Each row touched is kept first, as it was, in
  # artwork_credits_before_20261123 (a plain backup table, read only by
  # down/0). Drop it once the change has stood.

  @portraits [
    %{
      sets: [42, 45, 46, 53],
      size: {1613, 2000},
      title: "The Ecstatic Virgin Anna Katharina Emmerich",
      artist: "Gabriel von Max",
      year: "1885",
      url:
        "https://commons.wikimedia.org/wiki/File:Gabriel_von_Max_Die_ekstatische_Jungfrau_Katharina_Emmerich.jpg"
    },
    %{
      sets: [48],
      size: {1215, 2000},
      title: "St Ignatius of Loyola",
      artist: "Peter Paul Rubens",
      year: "c. 1620-22",
      url:
        "https://commons.wikimedia.org/wiki/File:St_Ignatius_of_Loyola_(1491-1556)_Founder_of_the_Jesuits.jpg"
    },
    %{
      sets: [59, 65],
      size: {1640, 2000},
      title: "Frederick William Faber",
      artist: "Joseph Brown",
      year: "c. 1869",
      url: "https://commons.wikimedia.org/wiki/File:Frederick_William_Faber.jpg"
    }
  ]

  def up do
    execute """
    CREATE TABLE artwork_credits_before_20261123 (
      tbl text NOT NULL,
      id bigint NOT NULL,
      image_title varchar(255),
      image_artist varchar(255),
      image_year varchar(255),
      image_source_url varchar(255),
      image_license varchar(255),
      updated_at timestamp
    )
    """

    for p <- @portraits do
      sets = Enum.join(p.sets, ", ")
      {width, height} = p.size

      set_rows = """
      FROM meditation_sets
      WHERE id IN (#{sets})
        AND image_key IS NOT NULL AND image_artist IS NULL
        AND image_width = #{width} AND image_height = #{height}
      """

      author_rows = """
      FROM authors
      WHERE id IN (SELECT author_id FROM meditation_sets WHERE id IN (#{sets}))
        AND image_key IS NOT NULL AND image_artist IS NULL
        AND image_width = #{width} AND image_height = #{height}
      """

      for {table, rows} <- [{"meditation_sets", set_rows}, {"authors", author_rows}] do
        execute """
        INSERT INTO artwork_credits_before_20261123
        SELECT '#{table}', id, image_title, image_artist, image_year, image_source_url,
               image_license, updated_at
        #{rows}
        """

        execute """
        UPDATE #{table}
        SET image_title = #{quote_literal(p.title)},
            image_artist = #{quote_literal(p.artist)},
            image_year = #{quote_literal(p.year)},
            image_source_url = #{quote_literal(p.url)},
            image_license = 'public_domain',
            updated_at = date_trunc('second', timezone('UTC', now()))
        WHERE id IN (SELECT id #{rows})
        """
      end
    end
  end

  def down do
    for table <- ["meditation_sets", "authors"] do
      execute """
      UPDATE #{table} t
      SET image_title = b.image_title, image_artist = b.image_artist,
          image_year = b.image_year, image_source_url = b.image_source_url,
          image_license = b.image_license, updated_at = b.updated_at
      FROM artwork_credits_before_20261123 b
      WHERE b.tbl = '#{table}' AND t.id = b.id
      """
    end

    execute "DROP TABLE artwork_credits_before_20261123"
  end

  defp quote_literal(value), do: "'" <> String.replace(value, "'", "''") <> "'"
end
