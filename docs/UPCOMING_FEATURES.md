# Upcoming Features Roadmap

This document captures the high-level objectives and design intent for planned functionality that extends LumenViae's prayer and meditation experience. It records intent, not commitments; items are removed as they ship.

## 1. Optional Petition Prayer Appendices
- Add an optional "petition prayer" section that can be appended to the end of each mystery.
- Surface the option in the UI so participants can decide whether to include the petition prayer when they conclude a mystery.
- Persist petition prayers alongside the mystery record so the same prayer can be reused, edited, or omitted on demand.

## 2. Petition Metadata During Mystery Creation
- Introduce an optional metadata field that allows content authors to supply a default petition prayer while authoring or editing mysteries.
- Ensure the new field does not block mystery creation; it should gracefully accept empty values.
- Expose the metadata to downstream features (rendering, exports, journaling) without forcing existing mysteries to change.

## 3. Resolution Journal Integration
- Provide users with the ability to capture personal resolutions tied to their petitions between mysteries and after completing all mysteries in a session.
- Support attaching resolutions at the granularity of a specific mystery/meditation pair as well as distributing the same resolution across each meditation within that mystery.
- Offer a dedicated "Resolution Journal" view where participants can review, edit, or export their saved resolutions.
- Persist journal entries so they can be retrieved in future sessions and linked back to the originating mysteries and meditations.

## 4. Completions for a Rosary prayed without a set

The prayer page can pray a category without a meditation set
(`/mysteries/:category/pray`, as the Scriptural Rosary or with the prayers
alone). Pressing Complete there records nothing in the completion figures,
because a completion belongs to a meditation set: `rosary_completions` has a
set and `Rosary.record_completion/3` takes a set id.

- Decide what such a completion is counted against: a category, a form, or a
  stand-in set.
- Change the completion resource, its checks (`GuardCompletions`, the visible-set check)
  and the admin figures in the same step, and edit the privacy policy if
  anything new is collected (docs/COMPLETION_ANALYTICS.md).
- The days-in-a-row count already includes these Rosaries, because it lives
  in the visitor's browser and does not ask the server.

## 5. Visitor Accounts

Only one kind of account exists today: the admin who signs in to the
console, with an email and password and no sign-up. Praying needs no account.

- If visitors are ever to have accounts, decide first what they would keep
  that the browser does not already keep for them (the place in a Rosary,
  the days in a row, the choices on the category page).
- Password recovery by email for admins, which needs a mailer production does
  not have today.
- Multi-factor authentication for the console.

## 6. Hardened Administration Experience

Partly shipped. In place today: every `/admin` route goes through
`LumenViaeWeb.Plugs.RequireAdmin` behind a password session, the browser
pipeline applies CSRF protection and secure browser headers, sign-in is
throttled per address and per email before the password is checked
(`LumenViaeWeb.Plugs.ThrottleSignIn`), every change to a mystery, meditation,
set or author records which admin made it and can be restored from the
History panel, and docs/PROD_ACCESS.md covers creating an admin and
resetting a password.

Still open:
- Logging of failed sign-in attempts. Only a failure that is not about the
  credentials is logged today.
- A log of administrative actions beyond edits to those four resources.
- A documented procedure for responding to suspicious activity.

These initiatives are intended to be iterative. Each feature can be delivered incrementally while maintaining the stability of the current production experience.
