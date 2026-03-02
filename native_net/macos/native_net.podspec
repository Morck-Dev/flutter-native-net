#
# macOS podspec - same approach as flutter_curl:
# vendored_frameworks + prepare_command to auto-download from GitHub Releases.
#
Pod::Spec.new do |s|
  s.name             = 'native_net'
  s.version          = '0.4.0'
  s.summary          = 'Flutter plugin for native HTTP networking using libcurl.'
  s.homepage         = 'https://github.com/Morck-Dev/flutter-native-net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  # Prebuilt native_net library (contains libcurl statically linked)
  s.vendored_frameworks = 'Frameworks/native_net.xcframework'

  # Auto-download from GitHub Releases if not present
  s.prepare_command = <<-CMD
    if [ ! -d "Frameworks/native_net.xcframework" ]; then
      url=https://github.com/Morck-Dev/flutter-native-net/releases/download/v0.4.0/native_net-xcframework.tar.gz
      file=native_net-xcframework.tar.gz
      echo "[native_net] Downloading XCFramework..."
      wget -O $file $url 2>/dev/null || curl -Lo $file $url
      mkdir -p Frameworks
      tar xzf $file -C Frameworks/
      rm -f $file
      echo "[native_net] XCFramework ready."
    fi
  CMD

  s.xcconfig = {
    'OTHER_LDFLAGS' => '-lz -framework Security -framework CoreFoundation -framework SystemConfiguration',
  }
end
