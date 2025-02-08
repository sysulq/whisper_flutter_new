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

  # 只包含插件源文件
  s.source_files = 'Classes/whisper_flutter_new.{cpp,h}'

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-lwhisper -lggml -lggml-blas -lggml-metal'
  }

  
  s.prepare_command = <<-CMD
    WHIPSER_VERSION=1.7.4
    if [ ! -d whisper.cpp ]; then
      wget -q https://github.com/ggerganov/whisper.cpp/archive/refs/tags/v${WHIPSER_VERSION}.tar.gz
      tar xf v${WHIPSER_VERSION}.tar.gz
      mv whisper.cpp-${WHIPSER_VERSION} whisper.cpp
      rm v${WHIPSER_VERSION}.tar.gz
    fi

    rm -rf build_whisper
    cmake -B build whisper.cpp \
      -DBUILD_SHARED_LIBS=ON \
      -DWHISPER_BUILD_TESTS=OFF \
      -DWHISPER_BUILD_EXAMPLES=OFF \
      -DWHISPER_COREML=1 \
      -DWHISPER_COREML_ALLOW_FALLBACK=1 \
      -DGGML_METAL=1 \
      -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
    
    cmake --build build --config Release
    cmake --install build --prefix build_whisper

    cp ./build/src/libwhisper.coreml.dylib build_whisper/lib/
    rm build_whisper/lib/libwhisper.dylib build_whisper/lib/libwhisper.1.dylib
    cp build_whisper/lib/libwhisper.1.7.4.dylib build_whisper/lib/libwhisper.dylib
    cp build_whisper/lib/libwhisper.1.7.4.dylib build_whisper/lib/libwhisper.1.dylib
  CMD

  s.vendored_libraries = [
    'build_whisper/lib/libggml.dylib',
    'build_whisper/lib/libwhisper.dylib',
    'build_whisper/lib/libggml-metal.dylib',
    'build_whisper/lib/libggml-blas.dylib',
    'build_whisper/lib/libwhisper.coreml.dylib',
    'build_whisper/lib/libwhisper.1.dylib',
    'build_whisper/lib/libwhisper.1.7.4.dylib'
  ].join(' ')

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'VALID_ARCHS' => 'arm64 x86_64',
    'OTHER_LDFLAGS' => '-lwhisper -lggml -lggml-metal -lggml-blas'
  }

  # # 头文件搜索路径
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => [
      '$(PODS_TARGET_SRCROOT)/build_whisper/include'
    ].join(' ')
  }

  # 框架依赖
  s.frameworks = ['Foundation', 'CoreML', 'Metal', 'MetalKit']

  s.swift_version = '5.0'
end
