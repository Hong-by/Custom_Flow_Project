# macOS 빌드 셋업 가이드

## 1단계: Flutter SDK 설치

```bash
# Homebrew로 설치 (권장)
brew install --cask flutter

# 또는 공식 사이트에서 다운로드
# https://docs.flutter.dev/get-started/install/macos

# 설치 확인
flutter doctor
```

## 2단계: macOS 플랫폼 생성

```bash
cd Custom_Flow_Project
flutter create --platforms=macos .
```

## 3단계: Entitlements 설정 (필수)

생성된 `macos/Runner/DebugProfile.entitlements`와 `macos/Runner/Release.entitlements`에
아래 키를 추가해야 합니다. 없으면 **WebView, HTTP, 인스턴스 잠금 모두 실패**합니다.

### macos/Runner/DebugProfile.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <!-- 네트워크 클라이언트 (WebView, HTTP 요청) -->
    <key>com.apple.security.network.client</key>
    <true/>
    <!-- 네트워크 서버 (인스턴스 중복 실행 방지 ServerSocket) -->
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

### macos/Runner/Release.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

## 4단계: MainFlutterWindow.swift 수정 (window_manager 필수)

`macos/Runner/MainFlutterWindow.swift`를 아래와 같이 수정:

```swift
import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentView = flutterViewController.view
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }

    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
```

## 5단계: macOS 최소 배포 타겟 설정

`macos/Podfile` 상단에서 최소 타겟을 확인:
```ruby
platform :osx, '10.14'
```

`macos/Runner.xcodeproj/project.pbxproj`에서 `MACOSX_DEPLOYMENT_TARGET`이
`10.14` 이상인지 확인하세요.

## 6단계: 의존성 설치 및 실행

```bash
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos
```

## 7단계: 릴리스 빌드

```bash
flutter build macos --release
# 결과: build/macos/Build/Products/Release/custom_flow.app
```

## 배포 (DMG 패키징)

```bash
# create-dmg 설치
brew install create-dmg

# DMG 생성
create-dmg \
  --volname "Custom-Flow" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "custom_flow.app" 175 120 \
  --hide-extension "custom_flow.app" \
  --app-drop-link 425 120 \
  "Custom-Flow-v1.0.0-macOS.dmg" \
  "build/macos/Build/Products/Release/custom_flow.app"
```

## 코드 서명 & 공증 (배포 시 필수)

```bash
# Apple Developer ID가 있는 경우
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/macos/Build/Products/Release/custom_flow.app

# 공증 (Notarization)
xcrun notarytool submit Custom-Flow-v1.0.0-macOS.dmg \
  --apple-id your@email.com \
  --team-id TEAM_ID \
  --password @keychain:AC_PASSWORD \
  --wait
```

## 트러블슈팅

### WebView가 빈 화면
- Entitlements에 `com.apple.security.network.client`가 있는지 확인

### 앱 실행 시 즉시 종료
- `com.apple.security.network.server`가 없으면 ServerSocket 바인딩 실패로 크래시
- 또는 이미 다른 인스턴스가 실행 중 (포트 47392 충돌)

### F1 핫키가 안 먹힘
- 시스템 환경설정 → 키보드 → "F1, F2 등의 키를 표준 기능 키로 사용" 활성화

### "확인되지 않은 개발자" 경고
- 코드 서명이 필요. 개발 테스트 시: 시스템 환경설정 → 보안 → "확인 없이 열기"
