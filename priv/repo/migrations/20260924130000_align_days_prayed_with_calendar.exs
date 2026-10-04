defmodule LumenViae.Repo.Migrations.AlignDaysPrayedWithCalendar do
  use Ecto.Migration

  # The seeded days_prayed strings matched no schedule at all: Joyful on
  # Saturday, Glorious on Thursday. The site, the iOS ScheduleService and
  # LumenViae.LiturgicalCalendar all follow the traditional schedule with
  # seasonal Sundays: Monday and Thursday Joyful, Tuesday and Friday
  # Sorrowful, Wednesday and Saturday Glorious, and Sunday Joyful in Advent,
  # Sorrowful in Lent and Glorious otherwise (Christmastide and Eastertide
  # included). Luminous is outside that rotation and is described the way
  # the site describes it. The Seven Sorrows chaplet has no weekday; it
  # takes the customary days the site names.
  #
  # Literal strings and raw SQL, so this never depends on today's modules.
  # Every update is guarded on the exact string the seeds wrote (NULL for
  # the Seven Sorrows), so a value changed through the admin UI is never
  # overwritten, and running it twice changes nothing.
  def up do
    execute """
    UPDATE mysteries SET days_prayed = 'Mondays and Thursdays, and Sundays of Advent'
    WHERE category = 'joyful' AND days_prayed = 'Mondays, Thursdays, and Saturdays'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Tuesdays and Fridays, and Sundays of Lent'
    WHERE category = 'sorrowful' AND days_prayed = 'Tuesdays and Fridays'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Wednesdays and Saturdays, and Sundays outside Advent and Lent'
    WHERE category = 'glorious' AND days_prayed = 'Wednesdays, Thursdays, and Sundays'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Thursdays in the modern schedule'
    WHERE category = 'luminous' AND days_prayed = 'Thursdays (modern schedule)'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Fridays in Lent and September 15th'
    WHERE category = 'seven_sorrows' AND days_prayed IS NULL
    """
  end

  # Reverts only rows still carrying exactly the strings this migration set.
  def down do
    execute """
    UPDATE mysteries SET days_prayed = 'Mondays, Thursdays, and Saturdays'
    WHERE category = 'joyful' AND days_prayed = 'Mondays and Thursdays, and Sundays of Advent'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Tuesdays and Fridays'
    WHERE category = 'sorrowful' AND days_prayed = 'Tuesdays and Fridays, and Sundays of Lent'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Wednesdays, Thursdays, and Sundays'
    WHERE category = 'glorious'
      AND days_prayed = 'Wednesdays and Saturdays, and Sundays outside Advent and Lent'
    """

    execute """
    UPDATE mysteries SET days_prayed = 'Thursdays (modern schedule)'
    WHERE category = 'luminous' AND days_prayed = 'Thursdays in the modern schedule'
    """

    execute """
    UPDATE mysteries SET days_prayed = NULL
    WHERE category = 'seven_sorrows' AND days_prayed = 'Fridays in Lent and September 15th'
    """
  end
end
