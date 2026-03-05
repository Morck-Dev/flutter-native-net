#
# macOS podspec (same approach as flutter_curl)
# Uses a separate native_net.framework (not xcframework)
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
  s.vendored_frameworks = 'Frameworks/native_net.framework'

  s.prepare_command = <<-CMD
    if [ ! -d "Frameworks/native_net.framework" ]; then
      url=https://github.com/Morck-Dev/flutter-native-net/releases/download/v0.4.0/native_net-macos-framework.zip
      file=native_net-macos-framework.zip
      echo "[native_net] Downloading macOS framework..."
      wget -O $file $url 2>/dev/null || curl -Lo $file $url
      mkdir -p Frameworks
      unzip -o $file -d Frameworks/
      # Rename to match vendored_frameworks
      if [ -d "Frameworks/native_net_macos.framework" ]; then
        mv Frameworks/native_net_macos.framework Frameworks/native_net.framework
      fi
      rm -f $file
      echo "[native_net] macOS framework ready."
    fi
  CMD

  s.xcconfig = {
    'OTHER_LDFLAGS' => '-lz -framework Security -framework CoreFoundation -framework SystemConfiguration',
  }
end
