# Catalog API Specification

このドキュメントは SubLife の「サブスク追加カタログ」機能で利用する API 仕様です。

## Base URL

- https://sublife.amania.jp/api

## Authentication

- `Info.plist` の `CatalogAPIKey` が存在する場合、以下ヘッダーを付与
    - `Authorization: Bearer <CatalogAPIKey>`
- 常に以下ヘッダーを付与
    - `Accept: application/json`

## Endpoints

### 1) Catalog App Search

- **Method**: `GET`
- **Path**: `/v1/catalog/apps/search`
- **Query**:
    - `q` (string, required): 検索キーワード

#### Request Example

```http
GET /v1/catalog/apps/search?q=netflix HTTP/1.1
Host: api.example.com
Accept: application/json
Authorization: Bearer <token>
```

#### 200 Response Example

```json
{
    "items": [
        {
            "id": "netflix",
            "name": "Netflix",
            "company": "Netflix, Inc.",
            "icon_url": "https://cdn.example.com/icons/netflix.png",
            "category": "video",
            "symbol_name_fallback": "play.rectangle.fill",
            "plans": [
                {
                    "id": "monthly-standard",
                    "name": "月額",
                    "price": 1490,
                    "currency_code": "JPY",
                    "billing_cycle": "monthly"
                },
                {
                    "id": "yearly-premium",
                    "name": "年額",
                    "price": 14900,
                    "currency_code": "JPY",
                    "billing_cycle": "yearly"
                }
            ]
        }
    ]
}
```

## Response Schema

### Root

- `items`: `CatalogAppSummary[]`

### CatalogAppSummary

- `id`: `string` (required)
- `name`: `string` (required)
- `company`: `string` (required)
- `icon_url`: `string (URL)` (optional)
- `category`: `string` (optional)
    - 期待値: `SubscriptionCategory` の rawValue
    - 不明値はクライアント側で `nil` として扱う
- `symbol_name_fallback`: `string` (optional)
- `plans`: `CatalogPlan[]` (optional, 未指定時は空配列扱い)

### CatalogPlan

- `id`: `string` (required)
- `name`: `string` (required)
- `price`: `number` (required, `>= 0` 推奨)
- `currency_code`: `string` (required)
    - 推奨: `JPY`, `USD`, `EUR`
- `billing_cycle`: `string` (required)
    - `monthly` | `yearly` | `installment`

## Client-side Behavior / Tolerance

- 空キーワードではリクエストしない
- HTTP 2xx 以外はエラー扱い
- `icon_url` が不正URLの場合は `nil` 扱い（画像なし表示）
- `category` が未知値の場合は `nil` 扱い
- `plans` が空のサービスは一覧表示するが選択不可

## Error Handling (Client)

- `invalidQuery`: 検索キーワード未入力
- `invalidRequest`: URL生成失敗
- `transport`: 通信失敗
- `invalidResponse`: HTTPURLResponse以外
- `httpStatus(Int)`: 非2xx
- `decoding`: JSONデコード失敗

## Timeout

- `Info.plist` の `CatalogAPITimeout`（秒）を利用
- 既定値: `15`

## Notes

- 会社名は `SubscriptionItem` に保存せず、選択時に `memo` 先頭へ `提供元: <company>` として反映
- API仕様変更時は `CatalogService.swift` とこの `API.md` を同時更新すること
