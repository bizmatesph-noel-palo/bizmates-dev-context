# コーチングポータル E-BOOK タブ追加 — 調査チケット

**日付:** 2026-08-19
**関連:** Redmine #12006 (coaching-ebook-delivery)
**関連計画:** `technical-notes/jira/proposals/01-ebook-delivery-implementation-plan.md` §4

---

## 要件サマリー

コーチングポータル（`/MyBizmates/student/coaching/portal`）に新たに2つのタブを追加する:

| タブ名 | 表示コンテンツ URL |
|---|---|
| テキストブック | `https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html` |
| ワークブック | `https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html` |

### UI 仕様

- 各タブを押すとモーダルで E-BOOK を表示する
- URL は非表示にする（ユーザーにリンクを見せない）
- E-BOOK は meclib の HTML ビューアーで閲覧（PDF ダウンロードではない）

> **注意:** 提供された2つのURLが同一です。テキストブックとワークブックで異なるURLが存在するか確認が必要です。

---

## 現状のコーチングポータル構造

**ページ:** `MBTI_frontend/src/pages/MyBizmates/student/coaching/portal/index.vue`
**メインコンポーネント:** `MBTI_frontend/src/components/pages/student/coaching/portal/CoachingPortal.vue`

現在のレイアウト:
```
┌─────────────────────────────────────────────────┐
│ coaching_portal                                  │
│ ┌─────────────────────┐ ┌─────────────────────┐ │
│ │ left_panel           │ │ right_panel          │ │
│ │ - NextSession        │ │ - SessionHistory     │ │
│ │ - ContractInfo       │ │                      │ │
│ │ - CoachingSummary    │ │                      │ │
│ └─────────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────────┘
```

現状タブUIは存在しない。追加が必要。

---

## 調査項目

### 1. テキストブック/ワークブック URL の確認

- [ ] 提供された2つのURLが同じ（`bizmatescoachingworkbook/book/index.html`）。テキストブック専用の別URLがあるか確認
- [ ] meclib の E-BOOK がiframe 埋め込みを許可しているか確認（`X-Frame-Options`, `Content-Security-Policy` ヘッダ）
- [ ] meclib viewer が iframe 内で正常に動作するか動作検証

### 2. UI/UX 設計

- [ ] タブの配置箇所を決定（ポータル上部にナビゲーションタブ？ 左パネル内にカード型タブ？）
- [ ] モーダルのサイズ・レスポンシブ対応方針
- [ ] SP（モバイル）での表示方法（モーダルか全画面か）
- [ ] モーダルを閉じる操作（×ボタン、オーバーレイクリック、ESC）

### 3. セキュリティ

- [ ] meclib URL を非表示にする方法:
  - iframeで埋め込み → ブラウザDevToolsではソース確認可能だが、UI上は非表示
  - バックエンドプロキシ → 完全に隠せるがパフォーマンス・コスト・meclibの利用規約に注意
  - **推奨:** iframe埋め込み（UI非表示で十分と判断）
- [ ] CSP設定で `frame-src` に `bizmatescoaching.meclib.jp` を許可する必要があるか

### 4. アクセス制御

- [ ] 既存の `coachingPageAccessCheck.js` ミドルウェアでポータルへのアクセスは既に制御済み
- [ ] E-BOOKタブの表示条件: アクティブなコーチング契約を持つ学生のみ（既存の `has_current_coaching` チェックと同一で十分か）
- [ ] 休憩中（rest period）の学生にも表示するか？

### 5. 既存実装計画との整合

`01-ebook-delivery-implementation-plan.md` §4 では:
- `coaching_page_info` に `coaching_ebooks` フィールドを追加する案
- PDF ダウンロードリンクを左パネルに表示する案

**今回の新要件との差分:**
| 項目 | 既存計画 | 新要件 |
|---|---|---|
| 表示形式 | リンクカード（新規タブで開く） | モーダル内 iframe |
| コンテンツ形式 | PDF | meclib HTML ビューアー |
| UI パターン | カード in left_panel | タブ + モーダル |
| URL可視性 | 見える | 非表示 |

→ 既存計画の§4（ポータル表示）は今回の要件で置き換える。§3（メール配信）は変更なし。

---

## 実装方針案

### フロントエンド (MBTI_frontend)

1. **タブコンポーネント新規作成:**
   `src/components/pages/student/coaching/portal/CoachingPortalEbooks.vue`
   - 「テキストブック」「ワークブック」の2タブを表示
   - タブクリックでモーダルを開く

2. **モーダルコンポーネント新規作成:**
   `src/components/pages/student/coaching/portal/CoachingEbookModal.vue`
   - iframe で meclib URL を埋め込み
   - URL はバックエンドから取得（ハードコードしない）
   - 閉じるボタン（×）+ オーバーレイクリックで閉じ

3. **CoachingPortal.vue にタブ配置:**
   配置候補:
   - A) ポータル上部にフルワイドのタブバー
   - B) left_panel 内に新カード
   - C) right_panel の session_history の上または下

4. **レスポンシブ:**
   - PC: モーダル（80vw × 80vh 程度）
   - SP: フルスクリーンモーダルまたは新ページ遷移

### バックエンド (MBTI_backend)

1. **GraphQL スキーマ:**
   既存計画通り `coaching_ebooks` フィールドを `coaching_page_info` に追加。ただしレスポンス型を調整:

   ```graphql
   type CoachingEbook {
       title: String!
       viewer_url: String!
       type: CoachingEbookType!
   }

   enum CoachingEbookType {
       TEXTBOOK
       WORKBOOK
   }
   ```

2. **Config** — `src/config/bco.php`:
   ```php
   'ebooks' => [
       [
           'title' => 'テキストブック',
           'viewer_url' => env('COACHING_EBOOK_TEXTBOOK_URL', 'https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html'),
           'type' => 'TEXTBOOK',
       ],
       [
           'title' => 'ワークブック',
           'viewer_url' => env('COACHING_EBOOK_WORKBOOK_URL', 'https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html'),
           'type' => 'WORKBOOK',
       ],
   ],
   ```

---

## ブロッカー / 確認事項

1. **meclib iframe 埋め込み可否** — これが不可の場合、代替策（新しいウィンドウで開く等）が必要
2. **テキストブックの正しいURL** — 現在2つとも同一URLが提供されている
3. **タブの配置位置** — デザインチームまたはPOの指示待ち
4. **CSP 設定変更** — Infra確認が必要かもしれない

---

## 見積もり（仮）

| タスク | 見積もり |
|---|---|
| meclib iframe 埋め込み動作検証 | 0.5d |
| バックエンド: スキーマ + サービス + config | 0.5d |
| フロントエンド: タブ + モーダル + iframe コンポーネント | 1.5d |
| レスポンシブ対応（PC/SP） | 0.5d |
| QA | 0.5d |
| **合計** | **3.5d** |

※ iframe埋め込みが不可の場合は方針変更で+1d程度
