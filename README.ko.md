# DeveloperNews

[English](README.md) | [한국어](README.ko.md)

아침마다 GitHub Trending, Hacker News, Reddit, 기술 블로그 여기저기를 돌아다니며 새 소식을 확인했다.
그게 귀찮아서 대신 돌아다녀 주는 앱을 만들었다.

DeveloperNews는 5개 플랫폼과 RSS 피드 30개에서 글을 모아 트렌드 점수를 매기고 주제별로 보여준다.
위에 작은 커뮤니티 계층을 얹어서, 글을 읽기만 하는 게 아니라 이야기도 나눌 수 있다.

## 기능

**읽기**

- GitHub Trending, Hacker News, Reddit, Dev.to, RSS 30개를 한곳에 모음
- 주제별 필터 — 웹, iOS, 안드로이드, 백엔드, AI, 보안, 프로덕트, 기타
- 소스별 정규화와 교차 언급 가산을 적용한 트렌드 점수
- Apple Translation 프레임워크를 이용한 제목·요약 온디바이스 번역
- Foundation Models로 기기에서 만드는 세 줄 요약
- 지역이나 Apple Intelligence 설정이 막는 경우엔 죽은 버튼 대신 그 이유를 안내
- 아예 못 돌리는 기기에서는 버튼을 두지 않고 설정 화면에서 상태 확인

**저장**

- 메모와 검색을 지원하는 북마크, URL 기준 중복 제거
- Share Extension — Safari를 비롯한 어느 앱에서든 글 저장
- 앱에서 연 북마크는 본문까지 남아, 신호가 없는 지하철에서도 열림
- Share Extension으로 저장만 한 글의 본문은 앱에서 한 번 연 뒤에 생김
- 저장해둘 생각을 못 한 글까지 되찾는 읽은 글 기록, 최신순

**위젯과 알림**

- 세 가지 크기의 홈 화면 위젯, 탭하면 사파리가 아니라 앱의 리더로 열림
- 피드 맨 위 소식을 하루 한 번 알림으로

**커뮤니티**

- 피드에 글을 공유하며 코멘트를 붙이거나, 독립된 게시글 작성
- 둘러보기(인기 / 최신)와 팔로잉 피드
- 1단계 대댓글을 지원하는 댓글, 게시글과 댓글 모두에 좋아요
- 다른 사용자 팔로우, 팔로워·팔로잉 목록, 이름 검색
- 스토리 단위 반응 — 누가 공유했는지와 무관하게 기사 URL 자체에 붙는 좋아요·댓글 수
- 좋아요·댓글·답글·새 팔로워를 모아 보는 활동 받은함, 미읽음 배지 포함
- 신고와 차단, 설정에서 차단 목록 관리

**계정**

- Apple, Google, 이메일 로그인
- 표시 이름, 이모지 아바타, 소개글 수정
- 본인이 작성한 콘텐츠까지 지우는 계정 삭제

## 아키텍처

### 콘텐츠 소스 — 전략 + 컴포지트

모든 소스가 `ContentSourceClient`를 구현하므로, 소스를 늘리는 일은 구현체를 하나 더 만드는 것으로 끝난다.

```
ContentSourceClient (프로토콜)
├── GitHubTrendingSourceClient
├── HackerNewsSourceClient
├── RedditSourceClient
├── DevToSourceClient
└── RSSSourceClient

CompositeContentSourceClient   <- 이것도 ContentSourceClient를 구현한다
  └── 위 전부를 병렬 실행한 뒤 병합·채점·중복 제거
```

`CompositeContentSourceClient`는 `withTaskGroup`으로 병렬 요청을 보낸다.

각 요청은 개별적으로 감싸두어 한 소스가 실패해도 새로고침 전체가 무너지지 않는다.
에러 화면을 띄우는 대신 어떤 소스를 못 불러왔는지 알려준다.

### 점수 산정

소스마다 지표가 달라서 원본 수치는 비교할 수 없다.
GitHub은 별, Reddit은 업보트, Hacker News는 포인트다.
그래서 이런 순서를 거친다.

1. **소스 신뢰 가산** — 눈에 띌 만한 소스에 고정 보너스를 조금 더한다
2. **소스별 정규화** — 각 소스 안에서 점수를 다시 스케일링해 서로 비교 가능하게 만든다
3. **중복 제거와 언급 가산** — 여러 소스에 걸친 같은 글은 하나로 합치고, 추가 언급 하나당 +4를 준다

### 상태와 뷰모델

`AppState`가 조립 지점이다. 여기 딸린 조각들은 한 객체에 몰아넣지 않고 관심사별로 나눠뒀다.

| 스토어 | 담당 |
|---|---|
| `FeedStore` | 조회, 캐시, 페이지네이션, 새로고침 실패 시 캐시 유지 |
| `SavedItemsStore` | 북마크, 정렬 순서, 스냅샷 |
| `ReadTracker` | 읽음 상태, 저장 개수 상한 |
| `SourceCategoryStore` | 켜져 있는 소스 |

화면은 뷰모델을 거친다.
서비스는 프로토콜(`AuthServicing`, `CommunityServicing`, `FeedPostServicing`, `ActivityServicing` 등) 뒤에 있고, 덕분에 테스트에서는 `AppState` 전체를 목으로 조립할 수 있다.

### 커뮤니티와 실시간

사용자가 만드는 데이터는 Firebase Auth와 Firestore가 받친다.
뉴스 수집은 평범한 REST 그대로이고, Firestore는 사용자가 직접 쓴 것에만 쓴다.

댓글·게시글·활동 받은함은 `addSnapshotListener`를 사용해서, 다른 기기에서 누른 좋아요가 바로 반영된다.

### 활동 받은함

서버가 없다.
행동을 한 클라이언트가 상대방 받은함에 알림을 직접 쓰는 구조라, 백엔드가 할 검증을 보안 규칙이 대신해야 한다.

`firestore.rules`는 알림이 주장하는 행동의 증거를 요구한다.

- 게시글의 `likedBy`에 그 사용자가 있는지
- 댓글이 실제로 존재하고 그 사람이 썼는지

또 알림마다 자기 내용에서 유도한 문서 id를 강제해서, 진짜 좋아요 하나를 100개 행으로 복제할 수 없게 막는다.

`scripts/test-firestore-rules.py`가 이 규칙을 Firestore 에뮬레이터에 대고 검증한다.
33개 항목 모두 클라이언트에게 맡길 수 없는 거부다.

`.github/workflows/firestore-rules.yml`이 규칙을 건드린 PR마다 이걸 돌리고, Firebase 배포는 그 통과를 조건으로 걸어두었다.
규칙과 그걸 필요로 하는 코드가 따로 놀지 않게 하기 위해서다.
로컬에서 돌릴 때는 이렇게 한다.

```bash
firebase emulators:exec --only firestore "python3 scripts/test-firestore-rules.py"
```

## 기술 스택

| | |
|---|---|
| **언어** | Swift 6.0, `MainActor` 기본 격리 기반 strict concurrency |
| **UI** | SwiftUI, `@Observable` |
| **동시성** | async/await, `TaskGroup`, actor |
| **네트워킹** | URLSession |
| **백엔드** | Firebase (Auth, Firestore) |
| **인증** | Apple, Google, 이메일 |
| **번역** | Apple Translation 프레임워크, 온디바이스 |
| **요약** | Foundation Models, 온디바이스 |
| **알림** | UserNotifications, BackgroundTasks로 일일 다이제스트 갱신 |
| **테스트** | Swift Testing |
| **익스텐션** | Share Extension, Widget Extension |
| **CI/CD** | GitHub Actions, fastlane |

## 요구 사항

- iOS 26.0 이상
- Xcode 26 이상
- Swift 6.0

Firebase 설정 파일은 저장소에 넣지 않았다.
본인의 `GoogleService-Info.plist`를 `DeveloperNews/`에 넣으면 된다.
없어도 앱은 실행되지만 커뮤니티 기능은 로그아웃 상태로 남는다.

## 테스트

```bash
xcodebuild test -project DeveloperNews.xcodeproj -scheme DeveloperNews \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

PR에서는 `.github/workflows/pr-check.yml`이 같은 테스트를 돌린다.
러너에서 쓸 수 있는 가장 최신 iPhone 시뮬레이터를 골라 실행한다.
`firestore.rules`가 바뀐 PR은 아래의 규칙 프로브도 함께 돈다.

## 라이선스

MIT — [LICENSE](LICENSE) 참고.

---

<details>
<summary><strong>Fastlane 설정</strong></summary>

### 준비

```bash
bundle install
cp .env.default .env
```

### App Store Connect API 키

`beta`나 `release`를 쓰기 전에 다음을 설정한다.

```bash
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
```

로컬에서는 `fastlane/.env`에 적어둬도 된다.

```bash
cp .env.default fastlane/.env
```

GitHub Actions에서는 저장소 시크릿에 다음을 추가한다.

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_KEY_CONTENT`
- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`

### 레인

```bash
bundle exec fastlane ios ci
bundle exec fastlane ios simulator_build
bundle exec fastlane ios archive
bundle exec fastlane ios beta
bundle exec fastlane ios release
bundle exec fastlane ios bump_build
```

### 참고

- `ci`는 `CI` 환경 변수가 있으면 fastlane CI 설정을 적용한 뒤 `simulator_build`를 실행한다
- `simulator_build`는 아카이브 없이 iOS 시뮬레이터용으로 빌드한다
- `archive`는 기기용 아카이브를 만들고 `build/DeveloperNews.ipa`로 내보낸다
- `beta`는 TestFlight에, `release`는 자동 제출 없이 App Store Connect에 업로드한다
- `beta`와 `release`는 위의 API 키 변수가 필요하다
- `bump_build`는 현재 버전의 최신 TestFlight 빌드 번호에 1을 더한다
- 아카이브 서명은 App Store Connect API로 프로비저닝 프로파일을 받아오고, 프로파일 매핑을 명시해 내보낸다
- `release` 브랜치에 푸시하면 `.github/workflows/release-beta.yml`이 돈다
- 내보내기 방식은 필요할 때 `FL_EXPORT_METHOD`로 바꾼다

</details>
