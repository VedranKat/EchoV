# Live Subtitle Eval

Local harness for generated-audio live subtitle baselines.

Run modes:

```bash
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --list
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --self-test
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --dry-run
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --run normal_narration
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --run normal_narration all
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --run all balanced
bash Tools/LiveSubtitleEval/run-live-subtitle-eval.sh --verify-latest
```

Real runs synthesize English Kokoro fixtures, feed them through the live subtitle chunker, transcribe chunks with the local Parakeet model, and write JSON reports under `.local/live_subtitle_eval/runs/`.

Reports split failures into:

- `accuracyPassed`: WER and missing-word thresholds.
- `capturePassed`: chunking/ASR chunk health.
- `timingPassed`: no unreadable subtitles and no active-speech blank gaps.
- `syncPassed`: caption lag stays bounded by `averageCaptionEndLagSeconds`, `longestCaptionEndLagSeconds`, and `longestCaptionStartLagSeconds`.

The timing model treats `ECHOV_LIVE_SUBTITLE_EVAL_MAX_LINES` as a rolling stack of visible subtitle rows. A row remains readable until its hold expires or enough newer rows push it out, which catches both too-fast replacement and cumulative drift. Use `youtube_narration` to catch sync loss during longer continuous speech.

Useful environment overrides:

- `ECHOV_LIVE_SUBTITLE_EVAL_SCENARIO=normal_narration,fast_continuous`
- `ECHOV_LIVE_SUBTITLE_EVAL_PRESET=balanced` or `fast,balanced,accurate`
- `ECHOV_LIVE_SUBTITLE_EVAL_VOICE=af_heart`
- `ECHOV_LIVE_SUBTITLE_EVAL_HOLD_SECONDS=2.2`
- `ECHOV_LIVE_SUBTITLE_EVAL_MAX_LINES=2`
- `ECHOV_PARAKEET_MODEL_PATH=/path/to/parakeet-tdt-0.6b-v3`
