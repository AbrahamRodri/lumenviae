defmodule LumenViae.Rosary.Completion.AppSourceTest do
  @moduledoc """
  Which app a completion came from, by its user agent: Android by name, iOS
  by Apple's networking stack, anything else other.
  """
  use ExUnit.Case, async: true

  alias LumenViae.Rosary.Completion.AppSource

  test "the Android app and Android's own stack are android" do
    assert AppSource.source("LumenViae-Android/1.0.0 (Android 14; Pixel 8)") == "android"
    assert AppSource.source("Dalvik/2.1.0 (Linux; U; Android 14; Pixel 8)") == "android"
  end

  test "every iOS build's CFNetwork agent is ios" do
    for agent <- [
          "app/5 CFNetwork/3826.500.111 Darwin/25.0.0",
          "app/4 CFNetwork/1568.100.1 Darwin/24.0.0",
          "LumenViae/1.0 CFNetwork/1494.0.7 Darwin/23.4.0",
          "Lumen%20Viae/1 CFNetwork/1410.0.3 Darwin/22.6.0"
        ] do
      assert AppSource.source(agent) == "ios", agent
    end
  end

  test "anything else, or no agent, is other" do
    for agent <- [
          nil,
          "",
          "SomeClient/1.0",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)",
          "CFNetwork/1494.0.7 Darwin/23.4.0",
          "app/5 CFNetwork/3826.500.111 Darwin/25.0.0 extra"
        ] do
      assert AppSource.source(agent) == "other", inspect(agent)
    end
  end
end
