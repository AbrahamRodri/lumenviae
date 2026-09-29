defmodule LumenViae.Rosary.VoicesConfigTest do
  @moduledoc """
  The production voice line-up in config/config.exs. The suite runs on its
  own fixture voices (config/test.exs), so this reads config.exs directly.
  """
  use ExUnit.Case, async: true

  @voices "config/config.exs"
          |> Config.Reader.read!(env: :prod, target: :host)
          |> get_in([:lumen_viae, :narration_voices])

  defp voice(slug), do: Enum.find(@voices, &(&1.slug == slug))

  test "Frederick is the default, offered as the male voice" do
    assert [%{slug: "frederick"}] = Enum.filter(@voices, &Map.get(&1, :default))

    assert %{name: "Male", model_id: "eleven_v4", eleven_labs_voice_id: "j9jfwdrw7BRfcR43Qohk"} =
             voice("frederick")
  end

  test "Marc Aurele is kept but retired in Frederick's favor" do
    assert %{hidden: true, replaced_by: "frederick"} = voice("male")
    refute Map.get(voice("male"), :default)
  end

  test "every borrowed recording comes from a configured voice" do
    slugs = Enum.map(@voices, & &1.slug)

    for v <- @voices, {kind, from} <- Map.get(v, :rosary_audio_from, %{}) do
      assert kind in [:prayer, :announcement, :verse, :book]
      assert from in slugs
      refute from == v.slug
    end
  end

  test "Arabella stays on the model her spoken Rosary was recorded with" do
    # Her 360 spoken-Rosary file names hash the model; changing it points
    # every one of them at a file that does not exist.
    assert %{model_id: "eleven_v3"} = voice("female")
  end
end
