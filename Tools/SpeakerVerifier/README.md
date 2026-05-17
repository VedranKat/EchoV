# EchoV Speaker Verifier

The Voice Gate "My voice only" feature calls `speaker_verifier.py` from EchoV.

For local development, create a project-local virtual environment:

```bash
python3 -m venv Tools/SpeakerVerifier/.venv
Tools/SpeakerVerifier/.venv/bin/python3 -m pip install torch torchaudio speechbrain
```

EchoV looks for Python in this order:

1. `ECHOV_SPEAKER_VERIFIER_PYTHON`
2. `~/Library/Application Support/EchoV/Runtimes/speaker-verifier/bin/python3`
3. `Tools/SpeakerVerifier/.venv/bin/python3`
4. common system/Homebrew `python3` locations
