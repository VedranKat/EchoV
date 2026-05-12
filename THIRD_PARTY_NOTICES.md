# EchoV Third-Party Licenses

EchoV includes, downloads, or directly supports the third-party components listed below. This file is provided for attribution and redistribution notices.

## Components

| Component | Use in EchoV | License | Source / attribution |
| --- | --- | --- | --- |
| FluidAudio SDK | Swift package used for local speech transcription | Apache-2.0 | https://github.com/FluidInference/FluidAudio |
| Parakeet v3 model | Downloadable or user-selected ASR model | CC-BY-4.0 | NVIDIA `nvidia/parakeet-tdt-0.6b-v3`, https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3 |
| Gemma 4 E2B IT GGUF | Downloadable or user-selected local post-processing model | Apache-2.0 | Unsloth `unsloth/gemma-4-E2B-it-GGUF`, derived from Google DeepMind Gemma 4 E2B IT, https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF |
| llama.cpp | Downloadable or user-selected local GGUF inference runtime | MIT | Copyright (c) 2023-2026 The ggml authors, https://github.com/ggml-org/llama.cpp |
| cpp-httplib | Bundled with llama.cpp for local HTTP serving | MIT | Copyright (c) 2017 yhirose, https://github.com/yhirose/cpp-httplib |
| nlohmann/json | Bundled with llama.cpp for JSON handling | MIT | Copyright (c) 2013-2026 Niels Lohmann, https://github.com/nlohmann/json |
| stb_image | Bundled with llama.cpp as an image decoder | Public Domain / MIT option | Sean Barrett and stb contributors, https://github.com/nothings/stb |
| miniaudio | Bundled with llama.cpp as an audio decoder | Public Domain / MIT-0 option | Copyright 2025 David Reid for MIT-0 option, https://github.com/mackron/miniaudio |
| subprocess.h | Bundled with llama.cpp as a process launching helper | Public Domain | https://github.com/sheredom/subprocess.h |
| VBx | Bundled with FluidAudio for speaker diarization clustering | Apache-2.0 | Copyright 2021-2024 BUT Speech@FIT, https://github.com/BUTSpeechFIT/VBx |
| fastcluster | Bundled with FluidAudio for hierarchical clustering | BSD-2-Clause | Copyright (c) 2011 Daniel Mullner; later changes copyright Google Inc., https://github.com/fastcluster/fastcluster |

## License Texts

### Apache License 2.0

Apache-2.0 licensed components are provided under the Apache License, Version 2.0.

Full license text: https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the Apache License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

### Creative Commons Attribution 4.0 International

The Parakeet v3 model is provided under CC-BY-4.0.

License deed: https://creativecommons.org/licenses/by/4.0/
Legal code: https://creativecommons.org/licenses/by/4.0/legalcode

Attribution: NVIDIA `nvidia/parakeet-tdt-0.6b-v3`.

### MIT License

MIT-licensed components are provided under the following terms, with each component's copyright holder listed above.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### BSD 2-Clause License

fastcluster is provided under the BSD 2-Clause License.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT INCLUDING NEGLIGENCE OR OTHERWISE ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### Public Domain Components

The public domain components listed above are included through upstream llama.cpp. Where a component offers an alternate permissive license, that option is noted in the component table.
