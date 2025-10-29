# Upcoming Features Roadmap

This document captures the high-level objectives and design intent for planned functionality that extends LumenViae's prayer and meditation experience.

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

## 4. User Accounts and Authentication
- Implement full user account management, including registration, login, password recovery, and profile maintenance.
- Introduce secure session handling and consider multi-factor authentication for enhanced protection.
- Provide role-based access controls to differentiate between general users, content authors, and administrators.

## 5. Hardened Administration Experience
- Audit the existing admin page to identify access control gaps and sensitive operations.
- Require authentication and appropriate authorization checks before granting access to administrative functionality.
- Employ defense-in-depth techniques (rate limiting, CSRF protection, secure headers, detailed logging) to protect administrative endpoints.
- Document operational procedures for managing administrator accounts and handling suspicious activity.

These initiatives are intended to be iterative. Each feature can be delivered incrementally while maintaining the stability of the current production experience.
