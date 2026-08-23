defmodule LumenViaeWeb.BotDetectionTest do
  use ExUnit.Case, async: true

  alias LumenViaeWeb.BotDetection

  describe "agents that are bots" do
    test "the crawlers that announce themselves" do
      for agent <- [
            "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
            "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
            "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)",
            "Mozilla/5.0 (compatible; SemrushBot/7~bl)",
            "GPTBot/1.0",
            "ClaudeBot/1.0",
            "facebookexternalhit/1.1"
          ] do
        assert BotDetection.bot?(agent), "expected a bot: #{agent}"
      end
    end

    test "the HTTP clients that show up when something is scripted" do
      for agent <- [
            "curl/8.4.0",
            "Wget/1.21.3",
            "python-requests/2.31.0",
            "Go-http-client/2.0",
            "PostmanRuntime/7.36.0",
            "node-fetch/1.0"
          ] do
        assert BotDetection.bot?(agent), "expected a bot: #{agent}"
      end
    end

    test "an unknown crawler that formats its agent conventionally" do
      assert BotDetection.bot?("SomeNewThing-bot/1.0")
      assert BotDetection.bot?("Mozilla/5.0 (compatible; spider; +http://example.com)")
    end
  end

  describe "agents that are people" do
    test "the browsers" do
      for agent <- [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
          ] do
        refute BotDetection.bot?(agent), "expected a person: #{agent}"
      end
    end

    test "the iOS app's own agent" do
      refute BotDetection.bot?("LumenViae/1.2 CFNetwork/1494.0.7 Darwin/23.4.0")
    end

    test "a phone whose model name happens to end in bot" do
      # The reason the generic match is left-bounded. A bare substring test
      # would throw away every Rosary prayed on one of these.
      refute BotDetection.bot?("Mozilla/5.0 (Linux; Android 10; Cubot X30) AppleWebKit/537.36")
    end

    test "a missing agent is unknown rather than accused" do
      refute BotDetection.bot?(nil)
      refute BotDetection.bot?("")
    end
  end
end
