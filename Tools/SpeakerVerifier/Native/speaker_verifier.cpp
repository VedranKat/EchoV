#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>
#include <onnxruntime_cxx_api.h>

#include <array>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr int kSampleRate = 16000;
constexpr int kFFTSize = 400;
constexpr int kWinLength = 400;
constexpr int kHopLength = 160;
constexpr int kPad = kFFTSize / 2;
constexpr int kBins = 201;
constexpr int kMels = 80;
constexpr int kEmbeddingDims = 192;
constexpr const char* kModelID = "speechbrain/spkrec-ecapa-voxceleb-onnx";

struct Options {
    std::string modelPath;
    std::string command;
    std::string audioPath;
    std::string profilePath;
};

std::string usage() {
    return
        "Usage:\n"
        "  speaker-verifier --model model/ecapa-speaker-v1.onnx enroll --audio audio.wav\n"
        "  speaker-verifier --model model/ecapa-speaker-v1.onnx score --audio audio.wav --profile profile.json";
}

[[noreturn]] void fail(const std::string& message) {
    std::cerr << "speaker-verifier: " << message << "\n";
    std::exit(1);
}

std::string osStatusDescription(OSStatus status) {
    std::ostringstream description;
    description << status;

    const uint32_t code = static_cast<uint32_t>(status);
    char chars[5] = {
        static_cast<char>((code >> 24) & 0xff),
        static_cast<char>((code >> 16) & 0xff),
        static_cast<char>((code >> 8) & 0xff),
        static_cast<char>(code & 0xff),
        '\0'
    };

    bool printable = true;
    for (int i = 0; i < 4; ++i) {
        if (!std::isprint(static_cast<unsigned char>(chars[i]))) {
            printable = false;
            break;
        }
    }
    if (printable) {
        description << " ('" << chars << "')";
    }

    return description.str();
}

void checkOSStatus(OSStatus status, const std::string& context) {
    if (status != noErr) {
        throw std::runtime_error(context + " (CoreAudio status " + osStatusDescription(status) + ")");
    }
}

void requireReadableFile(const std::string& path, const std::string& label) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        throw std::runtime_error("Could not read " + label + " at " + path + ".");
    }
}

std::string readFile(const std::string& path) {
    std::ifstream input(path);
    if (!input) {
        throw std::runtime_error("Could not read file at " + path + ".");
    }
    std::ostringstream buffer;
    buffer << input.rdbuf();
    return buffer.str();
}

std::vector<float> readFloatFile(const std::string& path, size_t expectedCount) {
    std::ifstream input(path, std::ios::binary | std::ios::ate);
    if (!input) {
        throw std::runtime_error("Could not read filterbank matrix at " + path + ".");
    }

    const auto byteCount = static_cast<std::streamoff>(input.tellg());
    const auto expectedBytes = static_cast<std::streamoff>(expectedCount * sizeof(float));
    if (byteCount != expectedBytes) {
        throw std::runtime_error(
            "Filterbank matrix at " + path + " has an unexpected size. Reinstall the speaker verifier runtime."
        );
    }

    input.seekg(0, std::ios::beg);
    std::vector<float> values(expectedCount);
    input.read(reinterpret_cast<char*>(values.data()), static_cast<std::streamsize>(values.size() * sizeof(float)));
    if (!input) {
        throw std::runtime_error("Could not read the complete filterbank matrix at " + path + ".");
    }
    return values;
}

std::string siblingFbankPath(const std::string& modelPath) {
    auto slash = modelPath.find_last_of('/');
    std::string parent = slash == std::string::npos ? "." : modelPath.substr(0, slash);
    return parent + "/fbank-80x201-f32.bin";
}

std::vector<float> loadAudio16kMono(const std::string& path) {
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        reinterpret_cast<const UInt8*>(path.c_str()),
        path.size(),
        false
    );
    if (!url) {
        throw std::runtime_error("Could not create URL for " + path);
    }

    ExtAudioFileRef file = nullptr;
    OSStatus status = ExtAudioFileOpenURL(url, &file);
    CFRelease(url);
    checkOSStatus(status, "Could not open audio file at " + path);

    AudioStreamBasicDescription clientFormat{};
    clientFormat.mSampleRate = kSampleRate;
    clientFormat.mFormatID = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    clientFormat.mBytesPerPacket = sizeof(float);
    clientFormat.mFramesPerPacket = 1;
    clientFormat.mBytesPerFrame = sizeof(float);
    clientFormat.mChannelsPerFrame = 1;
    clientFormat.mBitsPerChannel = 32;

    try {
        checkOSStatus(
            ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat),
            "Could not configure CoreAudio to decode " + path +
                ". Use WAV, AIFF, or CAF PCM audio, or convert the recording to 16 kHz mono WAV"
        );

        std::vector<float> audio;
        constexpr UInt32 chunkFrames = 4096;
        std::vector<float> chunk(chunkFrames);

        while (true) {
            AudioBufferList buffers{};
            buffers.mNumberBuffers = 1;
            buffers.mBuffers[0].mNumberChannels = 1;
            buffers.mBuffers[0].mDataByteSize = chunkFrames * sizeof(float);
            buffers.mBuffers[0].mData = chunk.data();

            UInt32 frames = chunkFrames;
            checkOSStatus(ExtAudioFileRead(file, &frames, &buffers), "Could not decode audio file at " + path);
            if (frames == 0) {
                break;
            }
            audio.insert(audio.end(), chunk.begin(), chunk.begin() + frames);
        }

        ExtAudioFileDispose(file);
        if (audio.empty()) {
            throw std::runtime_error("Audio file at " + path + " is empty.");
        }
        return audio;
    } catch (...) {
        ExtAudioFileDispose(file);
        throw;
    }
}

std::vector<float> hammingWindow() {
    std::vector<float> window(kWinLength);
    for (int i = 0; i < kWinLength; ++i) {
        window[i] = static_cast<float>(0.54 - 0.46 * std::cos(2.0 * M_PI * i / kWinLength));
    }
    return window;
}

std::vector<float> computeFeatures(const std::vector<float>& audio, const std::vector<float>& fbank) {
    std::vector<float> padded(audio.size() + 2 * kPad, 0.0f);
    std::copy(audio.begin(), audio.end(), padded.begin() + kPad);

    if (padded.size() < kWinLength) {
        throw std::runtime_error("Audio is too short for speaker verification.");
    }

    const int frames = static_cast<int>((padded.size() - kWinLength) / kHopLength) + 1;
    std::vector<float> features(frames * kMels, 0.0f);
    const auto window = hammingWindow();

    for (int frame = 0; frame < frames; ++frame) {
        const int offset = frame * kHopLength;
        float power[kBins]{};

        for (int bin = 0; bin < kBins; ++bin) {
            double real = 0.0;
            double imag = 0.0;
            for (int n = 0; n < kWinLength; ++n) {
                const double sample = static_cast<double>(padded[offset + n] * window[n]);
                const double angle = -2.0 * M_PI * bin * n / kFFTSize;
                real += sample * std::cos(angle);
                imag += sample * std::sin(angle);
            }
            power[bin] = static_cast<float>(real * real + imag * imag);
        }

        for (int mel = 0; mel < kMels; ++mel) {
            double value = 0.0;
            for (int bin = 0; bin < kBins; ++bin) {
                value += static_cast<double>(power[bin]) * fbank[bin * kMels + mel];
            }
            features[frame * kMels + mel] = static_cast<float>(10.0 * std::log10(std::max(value, 1e-10)));
        }
    }

    float maxValue = features[0];
    for (float value : features) {
        maxValue = std::max(maxValue, value);
    }
    const float floorValue = maxValue - 80.0f;
    for (float& value : features) {
        value = std::max(value, floorValue);
    }

    for (int mel = 0; mel < kMels; ++mel) {
        double mean = 0.0;
        for (int frame = 0; frame < frames; ++frame) {
            mean += features[frame * kMels + mel];
        }
        mean /= frames;
        for (int frame = 0; frame < frames; ++frame) {
            features[frame * kMels + mel] = static_cast<float>(features[frame * kMels + mel] - mean);
        }
    }

    return features;
}

std::vector<double> normalize(const std::vector<float>& embedding) {
    double norm = 0.0;
    for (float value : embedding) {
        norm += static_cast<double>(value) * value;
    }
    norm = std::sqrt(norm);
    if (!std::isfinite(norm) || norm == 0.0) {
        throw std::runtime_error("Could not create a usable speaker embedding.");
    }

    std::vector<double> normalized;
    normalized.reserve(embedding.size());
    for (float value : embedding) {
        normalized.push_back(static_cast<double>(value) / norm);
    }
    return normalized;
}

double cosine(const std::vector<double>& left, const std::vector<double>& right) {
    if (left.size() != right.size() || left.empty()) {
        throw std::runtime_error("Voice profile embedding dimensions do not match. Re-enroll the speaker profile.");
    }
    double leftNorm = 0.0;
    double rightNorm = 0.0;
    double dot = 0.0;
    for (size_t i = 0; i < left.size(); ++i) {
        dot += left[i] * right[i];
        leftNorm += left[i] * left[i];
        rightNorm += right[i] * right[i];
    }
    if (leftNorm == 0.0 || rightNorm == 0.0) {
        throw std::runtime_error("Could not compare speaker embeddings. Re-enroll the speaker profile.");
    }
    return dot / std::sqrt(leftNorm * rightNorm);
}

std::vector<double> parseProfileEmbedding(const std::string& path) {
    const std::string json = readFile(path);
    const auto key = json.find("\"embedding\"");
    if (key == std::string::npos) {
        throw std::runtime_error("Voice profile does not contain an embedding.");
    }
    const auto start = json.find('[', key);
    const auto end = json.find(']', start);
    if (start == std::string::npos || end == std::string::npos || end <= start) {
        throw std::runtime_error("Voice profile embedding is malformed.");
    }

    std::vector<double> values;
    std::string body = json.substr(start + 1, end - start - 1);
    std::stringstream stream(body);
    while (stream.good()) {
        double value = 0.0;
        stream >> value;
        if (stream.fail()) {
            break;
        }
        values.push_back(value);
        if (stream.peek() == ',') {
            stream.ignore();
        }
    }
    if (values.empty()) {
        throw std::runtime_error("Voice profile does not contain an embedding.");
    }
    if (values.size() != kEmbeddingDims) {
        throw std::runtime_error(
            "Voice profile embedding has " + std::to_string(values.size()) +
            " dimensions; expected " + std::to_string(kEmbeddingDims) +
            ". Re-enroll the speaker profile."
        );
    }
    return values;
}

class Verifier {
public:
    explicit Verifier(const std::string& modelPath)
        : env_(ORT_LOGGING_LEVEL_WARNING, "SpeakerVerifierRuntime"),
          sessionOptions_(),
          session_(nullptr),
          memoryInfo_(Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault)) {
        sessionOptions_.SetIntraOpNumThreads(1);
        sessionOptions_.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_BASIC);
        session_ = Ort::Session(env_, modelPath.c_str(), sessionOptions_);
    }

    std::vector<double> embed(const std::string& audioPath, const std::string& fbankPath) {
        const auto audio = loadAudio16kMono(audioPath);
        const auto fbank = readFloatFile(fbankPath, kBins * kMels);
        auto features = computeFeatures(audio, fbank);
        const int64_t frames = static_cast<int64_t>(features.size() / kMels);
        std::vector<int64_t> featureShape{1, frames, kMels};
        std::vector<float> featureLens{1.0f};
        std::vector<int64_t> lensShape{1};

        auto featureTensor = Ort::Value::CreateTensor<float>(
            memoryInfo_, features.data(), features.size(), featureShape.data(), featureShape.size()
        );
        auto lensTensor = Ort::Value::CreateTensor<float>(
            memoryInfo_, featureLens.data(), featureLens.size(), lensShape.data(), lensShape.size()
        );

        const char* inputNames[] = {"features", "feature_lens"};
        const char* outputNames[] = {"embedding"};
        std::array<Ort::Value, 2> inputs = {std::move(featureTensor), std::move(lensTensor)};
        auto outputs = session_.Run(Ort::RunOptions{nullptr}, inputNames, inputs.data(), inputs.size(), outputNames, 1);

        float* output = outputs[0].GetTensorMutableData<float>();
        auto info = outputs[0].GetTensorTypeAndShapeInfo();
        size_t count = info.GetElementCount();
        if (count != kEmbeddingDims) {
            throw std::runtime_error("Speaker verifier returned unexpected embedding dimensions.");
        }

        std::vector<float> embedding(output, output + count);
        return normalize(embedding);
    }

private:
    Ort::Env env_;
    Ort::SessionOptions sessionOptions_;
    Ort::Session session_;
    Ort::MemoryInfo memoryInfo_;
};

Options parseArgs(int argc, char** argv) {
    Options options;
    int index = 1;
    while (index < argc) {
        std::string arg = argv[index];
        if (arg == "--model" && index + 1 < argc) {
            options.modelPath = argv[index + 1];
            index += 2;
        } else {
            break;
        }
    }

    if (index >= argc) {
        fail("Missing command.\n" + usage());
    }
    options.command = argv[index++];

    while (index < argc) {
        std::string arg = argv[index];
        if (arg == "--audio" && index + 1 < argc) {
            options.audioPath = argv[index + 1];
            index += 2;
        } else if (arg == "--profile" && index + 1 < argc) {
            options.profilePath = argv[index + 1];
            index += 2;
        } else {
            fail("Unknown or incomplete argument: " + arg + "\n" + usage());
        }
    }

    if (options.modelPath.empty()) {
        fail("--model is required.\n" + usage());
    }
    if (options.audioPath.empty()) {
        fail("--audio is required.\n" + usage());
    }
    if (options.command == "score" && options.profilePath.empty()) {
        fail("--profile is required for score.\n" + usage());
    }
    if (options.command != "enroll" && options.command != "score") {
        fail("Unknown command: " + options.command + "\n" + usage());
    }

    return options;
}

void printEmbeddingJSON(const std::vector<double>& embedding) {
    std::cout << "{\"model_id\":\"" << kModelID << "\",\"embedding\":[";
    for (size_t i = 0; i < embedding.size(); ++i) {
        if (i != 0) {
            std::cout << ",";
        }
        std::cout.precision(17);
        std::cout << embedding[i];
    }
    std::cout << "]}\n";
}

} // namespace

int main(int argc, char** argv) {
    try {
        const auto options = parseArgs(argc, argv);
        const std::string fbankPath = siblingFbankPath(options.modelPath);
        requireReadableFile(options.modelPath, "ONNX model");
        requireReadableFile(options.audioPath, "audio file");
        requireReadableFile(fbankPath, "filterbank matrix");
        if (options.command == "score") {
            requireReadableFile(options.profilePath, "voice profile");
        }

        Verifier verifier(options.modelPath);
        const auto liveEmbedding = verifier.embed(options.audioPath, fbankPath);

        if (options.command == "enroll") {
            printEmbeddingJSON(liveEmbedding);
            return 0;
        }

        const auto profileEmbedding = parseProfileEmbedding(options.profilePath);
        const double similarity = cosine(liveEmbedding, profileEmbedding);
        std::cout.precision(17);
        std::cout << "{\"similarity\":" << similarity << "}\n";
        return 0;
    } catch (const std::exception& error) {
        fail(error.what());
    }
}
