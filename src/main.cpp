#include "main.h"
#include "whisper.h"

#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#include <cstdio>
#include <string>
#include <thread>
#include <vector>
#include <cmath>
#include <iostream>
#include <stdio.h>
#include "json/json.hpp"

using json = nlohmann::json;

char *jsonToChar(json jsonData) noexcept
{
    std::string result = jsonData.dump();
    char *ch = new char[result.size() + 1];
    strcpy(ch, result.c_str());
    return ch;
}

struct whisper_params
{
    int32_t seed = -1; // RNG seed, not used currently
    int32_t n_threads = std::min(4, (int32_t)std::thread::hardware_concurrency());

    int32_t n_processors = 1;
    int32_t offset_t_ms = 0;
    int32_t offset_n = 0;
    int32_t duration_ms = 0;
    int32_t max_context = -1;
    int32_t max_len = 0;
    int32_t best_of = 5;
    int32_t beam_size = -1;

    float word_thold = 0.01f;
    float entropy_thold = 2.40f;
    float logprob_thold = -1.00f;

    bool verbose = false;
    bool print_special_tokens = false;
    bool speed_up = false;
    bool translate = false;
    bool diarize = false;
    bool no_fallback = false;
    bool output_txt = false;
    bool output_vtt = false;
    bool output_srt = false;
    bool output_wts = false;
    bool output_csv = false;
    bool print_special = false;
    bool print_colors = false;
    bool print_progress = false;
    bool no_timestamps = false;
    bool split_on_word = false;

    std::string language = "auto";
    std::string prompt;
    std::string model = "models/ggml-tiny.bin";
    std::string audio = "samples/jfk.wav";
    std::vector<std::string> fname_inp = {};
    std::vector<std::string> fname_outp = {};
};

struct whisper_print_user_data
{
    const whisper_params *params;

    const std::vector<std::vector<float>> *pcmf32s;
};

// 创建专门的进度回调数据结构
struct progress_data {
    json* progress_json;
    const whisper_params* params;
};

// 全局变量存储Dart回调
static dart_progress_callback g_progress_callback = nullptr;

// 注册回调函数的实现
extern "C" FUNCTION_ATTRIBUTE void register_progress_callback(dart_progress_callback callback) {
    g_progress_callback = callback;
}

// 修改进度回调实现，添加调试输出
void progress_callback(struct whisper_context * ctx, struct whisper_state * state, int progress, void * user_data) {
    if (g_progress_callback == nullptr) {
        return;
    }
    
    float progress_float = static_cast<float>(progress) / 100.0f;
    g_progress_callback(progress_float);
}

json transcribe(json jsonBody) noexcept
{
    whisper_params params;

    params.n_threads = jsonBody["threads"];
    params.verbose = jsonBody["is_verbose"];
    params.translate = jsonBody["is_translate"];
    params.language = jsonBody["language"];
    params.print_special_tokens = jsonBody["is_special_tokens"];
    params.no_timestamps = jsonBody["is_no_timestamps"];
    params.model = jsonBody["model"];
    params.audio = jsonBody["audio"];
    params.split_on_word = jsonBody["split_on_word"];
    json jsonResult;
    jsonResult["@type"] = "transcribe";

    if (params.language != "" && params.language != "auto" && whisper_lang_id(params.language.c_str()) == -1)
    {
        jsonResult["@type"] = "error";
        jsonResult["message"] = "error: unknown language = " + params.language;
        return jsonResult;
    }

    if (params.seed < 0)
    {
        params.seed = static_cast<int32_t>(time(NULL));
    }

    // whisper init
    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context *ctx = whisper_init_from_file_with_params(params.model.c_str(), cparams);
    std::string text_result = "";
    const auto fname_inp = params.audio;
    // WAV input
    std::vector<float> pcmf32;
    {
        drwav wav;
        if (!drwav_init_file(&wav, fname_inp.c_str(), NULL))
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = " failed to open WAV file ";
            return jsonResult;
        }

        if (wav.channels != 1 && wav.channels != 2)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "must be mono or stereo";
            return jsonResult;
        }

        if (wav.sampleRate != WHISPER_SAMPLE_RATE)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 kHz";
            return jsonResult;
        }

        if (wav.bitsPerSample != 16)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 bit";
            return jsonResult;
        }

        auto n = static_cast<int>(wav.totalPCMFrameCount);

        std::vector<int16_t> pcm16;
        pcm16.resize(n * wav.channels);
        drwav_read_pcm_frames_s16(&wav, n, pcm16.data());
        drwav_uninit(&wav);

        // convert to mono, float
        pcmf32.resize(n);
        if (wav.channels == 1)
        {
            for (int i = 0; i < n; i++)
            {
                pcmf32[i] = float(pcm16[i]) / 32768.0f;
            }
        }
        else
        {
            for (int i = 0; i < n; i++)
            {
                pcmf32[i] = float(pcm16[2 * i] + pcm16[2 * i + 1]) / 65536.0f;
            }
        }
    }

    {
        if (params.language == "" && params.language == "auto")
        {
            params.language = "auto";
            params.translate = false;
        }
    }
    // run the inference
    {
        whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        
        wparams.progress_callback = progress_callback;
        wparams.progress_callback_user_data = nullptr;
        wparams.token_timestamps = true;
        wparams.translate = params.translate;
        wparams.language = params.language.c_str();
        wparams.n_threads = params.n_threads;
        wparams.split_on_word = params.split_on_word;

        if (whisper_full(ctx, wparams, pcmf32.data(), static_cast<int>(pcmf32.size())) != 0) {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "failed to process audio";
            return jsonResult;
        }

        // 获取所有segments并构建返回结果
        const int n_segments = whisper_full_n_segments(ctx);
        std::vector<json> segmentsJson;
        std::string full_text;

        // printf("Total segments: %d\n", n_segments);

        // 遍历所有segments
        for (int i = 0; i < n_segments; i++) {
            const char* text = whisper_full_get_segment_text(ctx, i);
            full_text += std::string(text);
            
            // printf("Segment %d: %s\n", i, text);

            json jsonSegment;
            const int64_t t0 = whisper_full_get_segment_t0(ctx, i);
            const int64_t t1 = whisper_full_get_segment_t1(ctx, i);

            jsonSegment["from_ts"] = t0;
            jsonSegment["to_ts"] = t1;
            jsonSegment["text"] = text;
            segmentsJson.push_back(jsonSegment);
        }

        // 构建最终返回结果
        jsonResult["text"] = full_text;
        jsonResult["segments"] = segmentsJson;  // 直接设置segments数组
        
        // Debug输出完整的JSON
        // printf("Final JSON: %s\n", jsonResult.dump(2).c_str());
    }
    
    whisper_free(ctx);
    return jsonResult;
}
extern "C"
{
    FUNCTION_ATTRIBUTE
    char *request(char *body)
    {
        try
        {
            json jsonBody = json::parse(body);
            json jsonResult;

            if (jsonBody["@type"] == "getTextFromWavFile")
            {
                try
                {
                    return jsonToChar(transcribe(jsonBody));
                }
                catch (const std::exception &e)
                {
                    jsonResult["@type"] = "error";
                    jsonResult["message"] = e.what();
                    return jsonToChar(jsonResult);
                }
            }
            if (jsonBody["@type"] == "getVersion")
            {
                jsonResult["@type"] = "version";
                jsonResult["message"] = "lib version: v1.0.1";
                return jsonToChar(jsonResult);
            }

            jsonResult["@type"] = "error";
            jsonResult["message"] = "method not found";
            return jsonToChar(jsonResult);
        }
        catch (const std::exception &e)
        {
            json jsonResult;
            jsonResult["@type"] = "error";
            jsonResult["message"] = e.what();
            return jsonToChar(jsonResult);
        }
    }
}