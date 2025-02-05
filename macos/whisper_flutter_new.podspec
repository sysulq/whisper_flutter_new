#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint whisper_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'whisper_flutter_new'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter FFI plugin for Whisper.cpp.'
  s.description      = <<-DESC
A Flutter FFI plugin for Whisper.cpp.
                       DESC
  s.homepage         = 'https://www.xcl.ink'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '田梓萱' => 'zixuanxcl@gmail.com' }
  s.source           = { :path => '.' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.public_header_files = 'Classes**/*.h'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'

  s.prepare_command = <<-CMD
    cmake -B build Classes/whisper.cpp/  \
          -DBUILD_SHARED_LIBS=ON \
          -DWHISPER_BUILD_TESTS=OFF \
          -DWHISPER_BUILD_EXAMPLES=OFF \
          -DGGML_METAL=ON \
          -DGGML_METAL_NDEBUG=ON \
          -DWHISPER_COREML=1 \
          -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
    cmake --build build --config Release
  CMD

  # 只包含插件源文件
  s.source_files = 'Classes/whisper_flutter_new.{cpp,h}'

  s.vendored_libraries = [
    'build/src/libwhisper.1.7.4.dylib',
    'build/ggml/src/libggml*.dylib',
    'build/ggml/src/ggml-blas/libggml-coreml.dylib',
    'build/ggml/src/ggml-metal/libggml-blas.dylib',
    'build/ggml/src/ggml-metal/libggml-metal.dylib'
  ]

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/include',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/ggml/include',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/src/coreml'
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/build/src',
      '$(PODS_TARGET_SRCROOT)/build/ggml/src',
      '$(PODS_TARGET_SRCROOT)/build/ggml/src/ggml-metal',
      '$(PODS_TARGET_SRCROOT)/build/ggml/src/ggml-blas',
    ].join(' '),
    'OTHER_LDFLAGS' => '-lwhisper -lggml -lggml-blas -lggml-metal'
  }

  # 头文件搜索路径
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/include',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/ggml/include',
      '$(PODS_TARGET_SRCROOT)/Classes/whisper.cpp/src/coreml'
    ].join(' '),
  }

  # 框架依赖
  s.frameworks = ['Foundation', 'CoreML', 'Metal', 'MetalKit']

  s.libraries = ['c++', 'stdc++']
  s.swift_version = '5.0'
end
