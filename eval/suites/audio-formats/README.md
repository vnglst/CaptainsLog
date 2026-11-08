# Audio container fixture

`quicktime.mov` contains the first three seconds of the synthetic transcription fixture `durins-volk.m4a`, remuxed into a genuine QuickTime container without re-encoding its audio. It is used by deterministic format conversion and pipeline discovery tests, separately from the transcription quality suite.

Regenerate from the repository root with:

```sh
ffmpeg -hide_banner -loglevel error -i eval/suites/transcribe/audio/durins-volk.m4a -t 3 -c:a copy -map_metadata -1 -f mov -y eval/suites/audio-formats/quicktime.mov
```

The application uses AVFoundation for conversion; FFmpeg is only used to prepare this committed test fixture.

`review-original.wav` is a one-second 220 Hz synthetic tone at 48 kHz mono PCM16.
`review-retake.wav` is a 0.2-second 440 Hz synthetic tone at 16 kHz mono PCM16.
Both were synthesized mathematically and contain no microphone or personal data.
The evaluation tooling tests use them for retake validation, mixed-rate splicing,
overlap rejection, duration shifts and original-file preservation.
