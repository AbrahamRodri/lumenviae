defmodule LumenViae.Audio.Pipeline do
  @moduledoc """
  Prepares stored meditation content for narration: the text ElevenLabs is
  sent, with the pause transforms of `LumenViae.Audio.TtsText` applied in
  the syntax of the voice's model (`ElevenLabs.pause_style/1`): audio tags
  for Eleven v3 and v4, SSML break tags for the rest.

  Stored content is never narrated verbatim: every recording, and every dry
  run describing one, takes its text from `speech_text/3`. The recording
  itself - the ElevenLabs call, the upload, and the guarantee that a clip
  is paid for once - is `LumenViae.Audio.Recording`, run from the
  narration jobs (see docs/ARCHITECTURE.md, "Background jobs").
  """

  alias LumenViae.Audio.{ElevenLabs, TtsText}
  alias LumenViae.Rosary.Voices

  @doc """
  The text ElevenLabs is sent for this content, in the pause syntax of the
  voice's model.
  """
  def speech_text(content, tts_annotations, voice \\ Voices.default()) do
    TtsText.to_speech_text(content, tts_annotations || [],
      pause_style: ElevenLabs.pause_style(voice.model_id)
    )
  end
end
