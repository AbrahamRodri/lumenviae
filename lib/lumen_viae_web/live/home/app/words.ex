defmodule LumenViaeWeb.Live.Home.App.Words do
  @moduledoc """
  The app page's words, in English and in Spanish: design's wording for
  direction C (reports/design/app-page/src/app.html), with the counts the
  library holds. Say only what the app does: the Missal and the chants
  are in Latin and English, so the Spanish says so too.
  """

  @ones_en ~w(zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen)
  @tens_en ~w(_ _ twenty thirty forty fifty sixty seventy eighty ninety)
  @hundreds_es ~w(_ ciento doscientos trescientos cuatrocientos quinientos seiscientos setecientos ochocientos novecientos)
  @ones_es ~w(cero uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince dieciséis diecisiete dieciocho diecinueve veinte veintiuno veintidós veintitrés veinticuatro veinticinco veintiséis veintisiete veintiocho veintinueve)
  @tens_es ~w(_ _ _ treinta cuarenta cincuenta sesenta setenta ochenta noventa)

  @doc "The page's words in `lang` (`:en` or `:es`), with the library's `counts`."
  def for(:es, %{chants: chants, prayers: prayers}) do
    %{
      title: "Lumen Viae para iPhone",
      description:
        "El Rosario en el iPhone: las meditaciones de los santos leídas para ti, el Rosario bíblico, el canto, las Horas y la Misa del día.",
      og_alt: "Pantallas de la app Lumen Viae para iPhone sobre un fondo azul noche",
      kicker: "Lumen Viae para iPhone",
      h1: "El Rosario, rezado dondequiera que estés",
      lede:
        "Las meditaciones de los santos entre las decenas, el Rosario bíblico y el Rosario entero rezado contigo, cuenta por cuenta.",
      free: "Gratis, sin cuenta",
      proof: [
        "#{chants} cantos",
        "#{prayers} oraciones",
        "El Misal de 1962",
        "Consagración en 33 días"
      ],
      rosary_kicker: "Un Rosario, paso a paso",
      rosary_title: "De la primera cuenta al Amén",
      rosary_body: "Cada misterio bajo su pintura, con la meditación de un santo leída para ti.",
      chant_kicker: "El canto",
      chant_title: "#{capitalize(spell_es(chants))} cantos, para oír y aprender",
      chant_body: "La partitura se ilumina línea por línea, en latín y en inglés.",
      tiles_kicker: "Y alrededor del Rosario",
      tiles_title: "La oración de la Iglesia, en tu bolsillo",
      tiles: [
        {"Horas de oración", "El Oficio divino, hora por hora."},
        {"La Misa de hoy", "El Misal de 1962, en latín e inglés."},
        {"Novenas", "Un día a la vez; la app lleva tu día."},
        {"Consagración", "Los 33 días de san Luis María."},
        {"Sin conexión, sin cuenta", "Reza sin internet. Todo queda en tu teléfono."},
        {"El libro de oraciones", "#{prayers} oraciones, del Ángelus a las Letanías lauretanas."}
      ],
      close_title: "Comienza el Rosario de hoy",
      close_body: "La app se abre en los misterios de hoy. Un toque, y estás rezando.",
      pause: "Pausar",
      play: "Reproducir",
      clips: %{
        "c1-player" =>
          "La app reza el primer misterio glorioso, la Resurrección, bajo su pintura.",
        "c6-hours" => "Las Horas de oración de hoy, con la hora presente iluminada.",
        "c7-prayers" => "El libro de oraciones se abre en el Ángelus, bajo su pintura."
      }
    }
  end

  def for(_en, %{chants: chants, prayers: prayers}) do
    %{
      title: "Lumen Viae for iPhone",
      description:
        "The Rosary on iPhone: meditations from the saints read to you, the Scriptural Rosary, the Audio Rosary, with chant, the Hours and the Mass of the day.",
      og_alt: "Three screens of the Lumen Viae iPhone app on a night-blue ground",
      kicker: "Lumen Viae for iPhone",
      h1: "The Rosary, prayed wherever you are",
      lede:
        "Meditations from the saints between the decades, the Scriptural Rosary, and the whole Rosary said with you, bead by bead.",
      free: "Free, no account",
      proof: [
        "#{chants} chants",
        "#{prayers} prayers",
        "The 1962 Missal",
        "A 33-day consecration"
      ],
      rosary_kicker: "One Rosary, step by step",
      rosary_title: "From the first bead to the Amen",
      rosary_body: "Each mystery under its painting, with a saint's meditation read to you.",
      chant_kicker: "The chant library",
      chant_title: "#{capitalize(spell_en(chants))} chants, to hear and to learn",
      chant_body: "The score lights line by line, in Latin and English.",
      tiles_kicker: "And around the Rosary",
      tiles_title: "The Church's prayer, in your pocket",
      tiles: [
        {"Hours of Prayer", "The Divine Office, hour by hour."},
        {"Today's Mass", "The 1962 Missal, Latin and English."},
        {"Novenas", "One day at a time; the app keeps your day."},
        {"Consecration", "The 33 days of St Louis de Montfort."},
        {"Offline, no account", "Pray without a connection. Everything stays on your phone."},
        {"The prayer book", "#{prayers} prayers, from the Angelus to the Litany of Loreto."}
      ],
      close_title: "Begin today's Rosary",
      close_body: "The app opens on today's mysteries. One tap, and you are praying.",
      pause: "Pause",
      play: "Play",
      clips: %{
        "c1-player" =>
          "The app praying the First Glorious Mystery, the Resurrection, under its painting.",
        "c6-hours" => "Today's Hours of Prayer, with the hour it is now lit.",
        "c7-prayers" => "The prayer book opening The Angelus under its painting."
      }
    }
  end

  @doc "A whole number from 1 to 999 in English words: 104 is \"a hundred and four\"."
  def spell_en(n) when n in 1..999 do
    {h, rest} = {div(n, 100), rem(n, 100)}

    hundreds = if h == 1, do: "a hundred", else: "#{small_en(h)} hundred"

    cond do
      h == 0 -> small_en(rest)
      rest == 0 -> hundreds
      true -> "#{hundreds} and #{small_en(rest)}"
    end
  end

  def spell_en(n), do: Integer.to_string(n)

  defp small_en(n) when n < 20, do: Enum.at(@ones_en, n)

  defp small_en(n) do
    tens = Enum.at(@tens_en, div(n, 10))
    if rem(n, 10) == 0, do: tens, else: "#{tens}-#{Enum.at(@ones_en, rem(n, 10))}"
  end

  @doc "A whole number from 1 to 999 in Spanish words: 104 is \"ciento cuatro\"."
  def spell_es(100), do: "cien"

  def spell_es(n) when n in 1..999 do
    {h, rest} = {div(n, 100), rem(n, 100)}
    hundreds = Enum.at(@hundreds_es, h)

    cond do
      h == 0 -> small_es(rest)
      rest == 0 -> hundreds
      true -> "#{hundreds} #{small_es(rest)}"
    end
  end

  def spell_es(n), do: Integer.to_string(n)

  defp small_es(n) when n < 30, do: Enum.at(@ones_es, n)

  defp small_es(n) do
    tens = Enum.at(@tens_es, div(n, 10))
    if rem(n, 10) == 0, do: tens, else: "#{tens} y #{Enum.at(@ones_es, rem(n, 10))}"
  end

  defp capitalize(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
end
