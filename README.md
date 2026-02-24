# Custom-Flow

> **"수많은 AI 채팅창과 SaaS 탭 사이에서 길을 잃고 계시지는 않나요?"**

**Custom-Flow**는 Claude, Gemini, Notion 등 매일 사용하는 다양한 AI 서비스와 웹 도구들이 브라우저 여기저기에 흩어져 있어 발생하는 비효율을 해결하고자 탄생한 **멀티 AI 워크스페이스 데스크톱 앱**입니다.

작업 흐름(Flow)을 방해하지 않으면서도, 필요한 서비스들을 하나의 공간에서 유기적으로 관리할 수 있도록 다양한 네이티브 편의 기능을 녹여냈습니다.

---

## ✨ 왜 Custom-Flow인가요?

* **통합 워크스페이스**: 여러 개의 AI 서비스와 웹 도구를 개별 창이 아닌 단일 앱 내 탭으로 깔끔하게 관리합니다.
* **즉각적인 접근 (Global Hotkey)**: 작업 중 언제 어디서든 `F1` 키 하나로 워크스페이스를 즉시 호출하고 숨길 수 있습니다.
* **생산성을 높이는 분할 뷰**: 두 개의 AI 모델을 나란히 띄워 답변을 비교하거나, Notion과 AI를 동시에 보며 작업할 수 있습니다.
* **쾌적한 사용자 경험**: AI랑 Saas 서비스 사용한다고 여러개의 창을 띄울 필요없이 디테일한 편의 기능을 통해 웹 서비스 그 이상의 네이티브 경험을 제공합니다.

[다운로드 (v1.0.0)](https://github.com/Hong-by/Ai_test/releases/latest)

---

## 주요 기능

| 기능 | 설명 |
|---|---|
| 웹뷰 탭 관리 | Claude, Gemini, Notion + 사용자 커스텀 탭 |
| 좌우 분할 뷰 | 두 탭을 나란히 표시, 드래그로 비율 조절 |
| 스마트 스크롤 | `elementFromPoint` 기반 — 중첩 스크롤 컨테이너 정확히 감지 |
| 시스템 트레이 | X 버튼 → 트레이로 숨김, 좌클릭으로 복원 |
| 글로벌 핫키 | **F1** 으로 창 표시/숨기기 (앱 포커스 없어도 동작) |
| 탭 키보드 네비게이션 | Tab / Shift+Tab 순환, Enter 활성화, Esc 취소 |
| 사이드바 토글 | Ctrl+B 또는 햄버거 버튼 |
| 탭 영속성 | 앱 재시작 후에도 탭 목록 유지 (SharedPreferences) |

---

## 스크린샷

<img width="1896" height="1218" alt="image" src="https://github.com/user-attachments/assets/ce5f93ae-1898-416f-b417-704b75173486" />


---

## 기술 스택

| 항목 | 패키지 |
|---|---|
| UI 프레임워크 | Flutter 3.x Desktop (Windows) |
| 상태관리 | flutter_riverpod ^2.5.1 |
| 웹뷰 | webview_windows ^0.4.0 (WebView2) |
| 창 관리 | window_manager ^0.3.9 |
| 시스템 트레이 | system_tray ^2.0.3 |
| 글로벌 핫키 | hotkey_manager ^0.2.3 |
| 폰트 | google_fonts ^6.2.1 (Noto Sans KR) |
| 영속성 | shared_preferences ^2.2.3 |
| 외부 링크 | url_launcher ^6.2.5 |

---

## 시작하기

### 요구사항

- Flutter SDK 3.x 이상
- Windows 10/11 (WebView2 런타임 포함 — Edge 설치 시 자동 포함)

### 설치 및 실행

```bash
git clone https://github.com/Hong-by/Ai_test.git
cd Ai_test
flutter pub get
flutter run -d windows
```

### 릴리스 빌드

```bash
flutter build windows --release
# 실행파일: build/windows/x64/runner/Release/custom_flow.exe
```

---

## 프로젝트 구조

```
lib/
├── main.dart                        # 엔트리포인트, 트레이·핫키 초기화
├── app.dart                         # MaterialApp + 다크테마 + 한국어 로케일
├── core/
│   ├── constants.dart               # 색상·레이아웃 상수
│   └── utils.dart                   # 파비콘 URL 등 유틸
├── models/
│   ├── tab_item.dart                # TabItem 모델
│   └── app_settings.dart            # 앱 설정 모델
├── services/
│   └── persistence_service.dart     # SharedPreferences 래퍼
├── providers/                       # Riverpod 상태
│   ├── tabs_provider.dart
│   ├── active_tab_provider.dart
│   ├── focused_tab_provider.dart
│   ├── sidebar_provider.dart
│   ├── split_view_provider.dart
│   ├── webview_registry_provider.dart
│   └── settings_provider.dart
└── ui/
    ├── shell/
    │   ├── app_shell.dart           # 반응형 루트 (600px 기준)
    │   ├── desktop_shell.dart       # 데스크톱 레이아웃
    │   ├── custom_titlebar.dart     # 커스텀 타이틀바
    │   └── sidebar_content.dart     # 사이드바
    ├── tabs/
    │   ├── webview_tab.dart         # 개별 웹뷰 탭
    │   ├── webview_tab_manager.dart # IndexedStack 탭 관리
    │   └── split_panel_content.dart # 분할 오른쪽 패널
    ├── modals/
    │   ├── add_tab_modal.dart       # 탭 추가 다이얼로그
    │   └── settings_modal.dart      # 환경설정 다이얼로그
    └── widgets/
        └── sidebar_tab_item.dart    # 사이드바 탭 행
```

---

## 단축키

| 단축키 | 동작 |
|---|---|
| **F1** | 창 표시 / 숨기기 (글로벌) |
| **Ctrl+B** | 사이드바 열기 / 닫기 |
| **Tab** | 다음 탭으로 포커스 이동 |
| **Shift+Tab** | 이전 탭으로 포커스 이동 |
| **Enter** | 포커스된 탭 활성화 |
| **Esc** | 탭 포커스 해제 |
