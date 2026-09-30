defmodule LumenViaeWeb.Live.PrivacyPolicy.Index do
  @moduledoc """
  Privacy policy page for the Lumen Viae iOS app and the website.

  Keep it in step with the app's own policy (`PrivacyPolicySheet`), its
  privacy manifest (`PrivacyInfo.xcprivacy`) and docs/COMPLETION_ANALYTICS.md.
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Privacy Policy")
     |> assign(
       :meta_description,
       "How Lumen Viae handles your information: what is collected, what is not, and how it is used."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-parchment min-h-screen">
      <div class="max-w-[70ch] mx-auto px-6 py-16 text-navy">
        <h1 class="font-cinzel text-4xl mb-3 text-navy">Privacy Policy</h1>
        <p class="font-cinzel text-xs tracking-[0.25em] uppercase text-gold-dark">
          Last updated: September 30, 2026
        </p>
        <.sacred_divider class="max-w-[210px]" />

        <p class="mb-6 font-garamond text-lg leading-relaxed">
          Lumen Viae ("we", "our", or "us") operates the Lumen Viae iOS application and the
          website at www.lumenviae.org. This policy describes what information we collect, how we
          use it, and your rights regarding that information. It covers both, and says where the
          two differ.
        </p>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Information We Collect</h2>
          <p class="font-garamond text-lg leading-relaxed mb-3">
            We collect very little, and nothing that could tell us who you are:
          </p>
          <ul class="list-disc list-inside font-garamond text-lg leading-relaxed space-y-2 pl-2">
            <li>
              <strong>Rosary completion data</strong> - When you finish praying a meditation set's
              Rosary, we record which set it was, when it was finished, and whether it was prayed in
              the app or on the website. This data is stored on our servers and is not linked to any
              personal identity. The app's other ways of praying - the Scriptural Rosary, the Holy
              Rosary and the guided first Rosary - send nothing at all.
            </li>
            <li>
              <strong>Approximate location</strong> - We record the approximate place a completed
              Rosary was prayed from: city, region and country. This is worked out from the network
              address your device connects with, which every website and app receives automatically
              as part of an ordinary internet request. We never ask your device for its location,
              and the app does not use iOS Location Services, so you will never see a location
              permission prompt from us. The accuracy is roughly city-level at best, and is often
              only correct to the country - it commonly reports the location of your internet
              provider rather than yours.
            </li>
            <li>
              <strong>Whether the Rosary was prayed aloud</strong> - With a completion, the app notes
              whether the Rosary was said aloud as the Whole Rosary (every prayer read aloud), and
              the website whether its Pray aloud switch was on, so we can tell how many people pray
              with the spoken Rosary. It is a yes or no, and nothing is recorded from your
              microphone or voice.
            </li>
            <li>
              <strong>Request logs</strong> - Like any web server, ours writes a line for each
              request it answers: the path that was asked for (such as a meditation set), the time,
              whether it succeeded and how long it took. These logs do not record your network
              address, and they do not record your device, app version or system version. The user
              agent - the short description of the browser or app that every request carries - is
              read only to turn away automated crawlers, and is not kept.
            </li>
          </ul>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Information We Do Not Collect</h2>
          <ul class="list-disc list-inside font-garamond text-lg leading-relaxed space-y-2 pl-2">
            <li>We do not collect your name, email address, or any account information.</li>
            <li>We do not require you to create an account or log in.</li>
            <li>
              We do not use advertising networks or sell data to third parties, and neither the app
              nor the website carries analytics or advertising code from anyone else.
            </li>
            <li>
              We do not use GPS or iOS Location Services, and we never ask your device where it is.
              The approximate location described above is worked out from your network address
              alone.
            </li>
            <li>
              We do not save your full network address. Our server holds it in memory for about a
              day at most - to look up an approximate place, to avoid looking the same address up
              twice, and to limit abuse - and saves only a truncated version of it: the first three
              parts of an IPv4 address, or the first three groups of an IPv6 one. That is enough to
              tell one city from another, not enough to identify a household. On the website, the
              address is also carried in the site's session cookie, in your own browser, so that
              the prayer page can place a completed Rosary.
            </li>
            <li>
              We do not attach any account, device or installation identifier to a completion.
              Two Rosaries prayed on the same phone cannot be linked to each other, which means we
              cannot build a history of your praying and cannot follow you between visits.
            </li>
          </ul>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">What Stays on Your Phone</h2>
          <p class="font-garamond text-lg leading-relaxed">
            In the app, almost everything. Your journal, your prayer record and streak, your place in
            every book, your Chapel and your settings are kept on your device and never sent to us.
            They leave it only in your iPhone's own iCloud Backup, if you have it turned on, under
            Apple's privacy policy.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            Daily reminders and the Angelus bell are scheduled on your phone by iOS. We send no push
            notifications.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">How We Use the Information</h2>
          <p class="font-garamond text-lg leading-relaxed">
            Completion data is used solely to track aggregate prayer statistics for the purpose of
            improving the app and understanding which meditations are most used, when they are
            prayed, and roughly where in the world they are being prayed. It is never sold, and it
            is never shared with third parties for their own purposes.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Data Retention</h2>
          <p class="font-garamond text-lg leading-relaxed">
            Completion records are retained indefinitely in an anonymized form. Because no personal
            identifiers are attached to completion records, and because network addresses are
            truncated before they are stored, we are unable to identify or delete data belonging to
            a specific individual upon request. This is a deliberate consequence of collecting so
            little: there is no key by which your records could be found, including by us.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Third-Party Services</h2>
          <p class="font-garamond text-lg leading-relaxed">
            The website and our server are hosted by Fly.io. Every request to the website, and every
            request the app makes to us, passes through Fly.io's network, which sees your network
            address as any host does.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            Our recordings - the meditations' narration and the prayers said aloud - are served from
            Amazon Web Services (AWS) S3 through pre-signed URLs, and the meditation sets' paintings
            from AWS S3 as well. AWS may log standard server-side access metadata (IP address,
            timestamp) in accordance with their own privacy practices. We do not receive or store
            this metadata.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            To turn a network address into an approximate city and country, that address is sent to
            a third-party geolocation service (currently ipapi.co), which returns the place and
            nothing else. Only the address is sent. Nothing about which Rosary was prayed, or when,
            or anything else from this app or website, is sent with it.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            Some of what the app shows is fetched directly from other sites, not through us: the
            Daily Missal from Missale Meum, and the Spiritual Reading shelf's books and recordings
            from Project Gutenberg and LibriVox, whose recordings are kept by the Internet Archive.
            Each receives the request itself - which day of the Missal, which book or recording -
            and your network address with it, as any website does, and nothing more.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            The website's typefaces are loaded from Google Fonts, which likewise sees the request.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Children's Privacy</h2>
          <p class="font-garamond text-lg leading-relaxed">
            Lumen Viae does not knowingly collect information from children under the age of 13.
            The app contains no account creation, social features, or targeted content, and is
            suitable for all ages.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Changes to This Policy</h2>
          <p class="font-garamond text-lg leading-relaxed">
            We may update this privacy policy from time to time. Any changes will be posted at this
            URL with an updated revision date. Continued use of the app after changes constitutes
            acceptance of the revised policy.
          </p>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Contact</h2>
          <p class="font-garamond text-lg leading-relaxed">
            If you have questions about this privacy policy, you may contact us at:
            <a href="mailto:rodriguez.abrahamdev@gmail.com" class="text-gold-dark underline">
              rodriguez.abrahamdev@gmail.com
            </a>
          </p>
        </section>
      </div>
    </div>
    """
  end
end
