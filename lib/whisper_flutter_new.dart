/*
 * Copyright (c) 田梓萱[小草林] 2021-2024.
 * All Rights Reserved.
 * All codes are protected by China's regulations on the protection of computer software, and infringement must be investigated.
 * 版权所有 (c) 田梓萱[小草林] 2021-2024.
 * 所有代码均受中国《计算机软件保护条例》保护，侵权必究.
 */

import "dart:convert";
import "dart:ffi";
import "dart:io";

import "package:ffi/ffi.dart";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "package:whisper_flutter_new/bean/_models.dart";
import "package:whisper_flutter_new/bean/whisper_dto.dart";
import "package:whisper_flutter_new/download_model.dart";
import "package:whisper_flutter_new/whisper_bindings_generated.dart";
import 'package:flutter/widgets.dart' show WidgetsBinding;
export "package:whisper_flutter_new/bean/_models.dart";
export "package:whisper_flutter_new/download_model.dart" show WhisperModel;

/// Entry point of whisper_flutter_plus
class Whisper {
  /// [model] is required
  /// [modelDir] is path where downloaded model will be stored.
  Whisper({required this.model, this.modelDir, this.downloadHost}) {
    // 在构造函数中初始化NativeCallable
    _nativeCallback = NativeCallable<Void Function(Double)>.isolateLocal(
      _progressHandler,
    );
  }

  /// model used for transcription
  final WhisperModel model;

  /// override of model storage path
  final String? modelDir;

  // override of model download host
  final String? downloadHost;

  // 实例级别的回调函数引用
  late final NativeCallable<Void Function(Double)> _nativeCallback;
  void Function(double)? _onProgress;

  // 处理进度回调
  void _progressHandler(double progress) {
    if (kDebugMode) {
      print("Progress: ${progress.toDouble()}");
    }
    _onProgress?.call(progress.toDouble());
  }

  DynamicLibrary _openLib() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open("libwhisper.so");
    } else {
      return DynamicLibrary.process();
    }
  }

  Future<String> _getModelDir() async {
    if (modelDir != null) {
      return modelDir!;
    }
    final Directory libraryDirectory = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    return libraryDirectory.path;
  }

  Future<void> _initModel() async {
    final String modelDir = await _getModelDir();
    final File modelFile = File(model.getPath(modelDir));
    final bool isModelExist = modelFile.existsSync();
    if (isModelExist) {
      if (kDebugMode) {
        debugPrint("Use existing model ${model.modelName}");
      }
      return;
    } else {
      await downloadModel(
          model: model, destinationPath: modelDir, downloadHost: downloadHost);
    }
  }

  Future<Map<String, dynamic>> _request({
    required WhisperRequestDto whisperRequest,
    void Function(double)? onProgress,
  }) async {
    if (model != WhisperModel.none) {
      await _initModel();
    }

    _onProgress = onProgress;
    final bindings = WhisperFlutterBindings(_openLib());

    try {
      bindings.register_progress_callback(_nativeCallback.nativeFunction);

      final data = whisperRequest.toRequestString().toNativeUtf8();
      final res = bindings.request(data.cast<Char>());
      final result =
          json.decode(res.cast<Utf8>().toDartString()) as Map<String, dynamic>;

      malloc.free(data);
      malloc.free(res);

      return result;
    } finally {
      _onProgress = null;
    }
  }

  /// Transcribe audio file to text
  Future<WhisperTranscribeResponse> transcribe({
    required TranscribeRequest transcribeRequest,
    void Function(double)? onProgress,
  }) async {
    final String modelDir = await _getModelDir();
    final result = await _request(
      whisperRequest: TranscribeRequestDto.fromTranscribeRequest(
        transcribeRequest,
        model.getPath(modelDir),
      ),
      onProgress: onProgress,
    );

    if (result["text"] == null) {
      throw Exception(result["message"]);
    }
    return WhisperTranscribeResponse.fromJson(result);
  }

  /// Get whisper version
  Future<String?> getVersion() async {
    final Map<String, dynamic> result = await _request(
      whisperRequest: const VersionRequest(),
    );

    final WhisperVersionResponse response = WhisperVersionResponse.fromJson(
      result,
    );
    return response.message;
  }

  // 添加dispose方法清理资源
  void dispose() {
    _nativeCallback.close();
  }
}
