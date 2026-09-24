defmodule LumenViaeWeb.Live.PrivacyPolicy.Index do
  @moduledoc """
  Privacy policy page for the Lumen Viae iOS app.
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
          Last updated: September 24, 2026
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
            We collect minimal information necessary to provide the app's functionality:
          </p>
          <ul class="list-disc list-inside font-garamond text-lg leading-relaxed space-y-2 pl-2">
            <li>
              <strong>Rosary completion data</strong> - When you complete a Rosary or meditation set,
              we record which set was completed and when, and whether it was prayed in the app or on
              the website. This data is stored on our servers and is not linked to any personal
              identity.
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
              <strong>Time zone and language region</strong> - When you complete a Rosary in the
              app, it may send the time zone and language region your device is set to, so we can
              understand when Rosaries are prayed. These are settings you chose; reading them
              requires no permission and does not involve Location Services.
            </li>
            <li>
              <strong>Whether the Rosary was prayed aloud</strong> - When you complete a Rosary,
              the app or website may note whether the spoken Rosary (every prayer read aloud) was
              switched on, so we can tell how many people pray with it. It is a yes or no, and
              nothing is recorded from your microphone or voice.
            </li>
            <li>
              <strong>Device information</strong> - Standard technical data sent with API requests
              (e.g., app version, iOS version) used for debugging and compatibility.
            </li>
          </ul>
        </section>

        <section class="mt-10 pt-8 border-t border-gold/20">
          <h2 class="font-cinzel text-2xl mb-4 text-navy">Information We Do Not Collect</h2>
          <ul class="list-disc list-inside font-garamond text-lg leading-relaxed space-y-2 pl-2">
            <li>We do not collect your name, email address, or any account information.</li>
            <li>We do not require you to create an account or log in.</li>
            <li>We do not use advertising networks or sell data to third parties.</li>
            <li>
              We do not use GPS or iOS Location Services, and we never ask your device where it is.
              The approximate location described above is worked out from your network address
              alone.
            </li>
            <li>
              We do not store your full network address. It is used to look up an approximate place
              and to limit abuse, and only a truncated version of it is written down - enough to
              tell one city from another, not enough to identify a household.
            </li>
            <li>
              We do not attach any account, device or installation identifier to a completion.
              Two Rosaries prayed on the same phone cannot be linked to each other, which means we
              cannot build a history of your praying and cannot follow you between visits.
            </li>
          </ul>
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
            Audio files for meditations are served via Amazon Web Services (AWS) S3 pre-signed URLs.
            AWS may log standard server-side access metadata (IP address, timestamp) in accordance
            with their own privacy practices. We do not receive or store this metadata.
          </p>
          <p class="font-garamond text-lg leading-relaxed mt-4">
            To turn a network address into an approximate city and country, that address is sent to
            a third-party geolocation service (currently ipapi.co), which returns the place and
            nothing else. Only the address is sent. Nothing about which Rosary was prayed, or when,
            or anything else from this app or website, is sent with it.
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
