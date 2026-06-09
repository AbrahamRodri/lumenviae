defmodule LumenViaeWeb.Live.PrivacyPolicy.Index do
  @moduledoc """
  Privacy policy page for the Lumen Viae iOS app.
  """
  use LumenViaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Privacy Policy")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-6 py-12 text-[#1a1a2e]">
      <h1 class="font-cinzel text-3xl font-bold mb-2 text-[#1a1a2e]">Privacy Policy</h1>
      <p class="text-sm text-gray-500 mb-8">Last updated: June 8, 2026</p>

      <p class="mb-6 font-crimson text-lg leading-relaxed">
        Lumen Viae ("we", "our", or "us") operates the Lumen Viae iOS application. This policy
        describes what information we collect, how we use it, and your rights regarding that information.
      </p>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Information We Collect</h2>
        <p class="font-crimson text-lg leading-relaxed mb-3">
          We collect minimal information necessary to provide the app's functionality:
        </p>
        <ul class="list-disc list-inside font-crimson text-lg leading-relaxed space-y-2 pl-2">
          <li>
            <strong>Rosary completion data</strong> - When you complete a Rosary or meditation set,
            we record which set was completed and when. This data is stored on our servers and is
            not linked to any personal identity.
          </li>
          <li>
            <strong>Device information</strong> - Standard technical data sent with API requests
            (e.g., app version, iOS version) used for debugging and compatibility.
          </li>
        </ul>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Information We Do Not Collect</h2>
        <ul class="list-disc list-inside font-crimson text-lg leading-relaxed space-y-2 pl-2">
          <li>We do not collect your name, email address, or any account information.</li>
          <li>We do not require you to create an account or log in.</li>
          <li>We do not use advertising networks or sell data to third parties.</li>
          <li>We do not track your location.</li>
        </ul>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">How We Use the Information</h2>
        <p class="font-crimson text-lg leading-relaxed">
          Completion data is used solely to track aggregate prayer statistics for the purpose of
          improving the app and understanding which meditations are most used. It is never shared
          with third parties.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Data Retention</h2>
        <p class="font-crimson text-lg leading-relaxed">
          Completion records are retained indefinitely in an anonymized form. Because no personal
          identifiers are attached to completion records, we are unable to identify or delete data
          belonging to a specific individual upon request.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Third-Party Services</h2>
        <p class="font-crimson text-lg leading-relaxed">
          Audio files for meditations are served via Amazon Web Services (AWS) S3 pre-signed URLs.
          AWS may log standard server-side access metadata (IP address, timestamp) in accordance
          with their own privacy practices. We do not receive or store this metadata.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Children's Privacy</h2>
        <p class="font-crimson text-lg leading-relaxed">
          Lumen Viae does not knowingly collect information from children under the age of 13.
          The app contains no account creation, social features, or targeted content, and is
          suitable for all ages.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Changes to This Policy</h2>
        <p class="font-crimson text-lg leading-relaxed">
          We may update this privacy policy from time to time. Any changes will be posted at this
          URL with an updated revision date. Continued use of the app after changes constitutes
          acceptance of the revised policy.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="font-cinzel text-xl font-semibold mb-3 text-[#d4af37]">Contact</h2>
        <p class="font-crimson text-lg leading-relaxed">
          If you have questions about this privacy policy, you may contact us at:
          <a href="mailto:rodriguez.abrahamdev@gmail.com" class="text-[#d4af37] underline">
            rodriguez.abrahamdev@gmail.com
          </a>
        </p>
      </section>
    </div>
    """
  end
end
