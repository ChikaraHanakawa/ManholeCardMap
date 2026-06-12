# ManholeCardMap

マンホールカードの配布場所を地図上で探せる iOS アプリです。
全国のマンホールカード配布場所をマップに表示し、現在地からの経路検索やカードの収集記録ができます。

<p>
  <img src="https://img.shields.io/badge/platform-iOS-blue" alt="Platform: iOS">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT">
  <img src="https://img.shields.io/badge/version-2.0-brightgreen" alt="Version 2.0">
</p>

## 機能

- 🗺️ **配布場所マップ表示** — 全国のマンホールカード配布場所を地図上にピン表示。地方ごとに色分けされ、ひと目で地域がわかります
- 🧭 **経路検索** — 現在地から配布場所までの経路を車・徒歩で検索し、距離と所要時間を表示。公共交通機関は純正マップアプリと連携して乗換案内を表示します
- 🔍 **絞り込み** — 地方・都道府県・弾（シリーズ）・収集状態でカードを絞り込み
- ✅ **収集記録** — 入手したカードを「収集済み」として記録。地図上ではグレー表示になり、未収集のカードがすぐわかります
- 📋 **一覧表示** — 配布場所を一覧で確認。名前検索や「近い順」「弾の順」での並べ替えに対応
- 🎴 **カード詳細** — カード画像・配布場所・配布時間・電話番号などの詳細情報を表示

## スクリーンショット

<!-- TODO: スクリーンショットを追加 -->

## 動作環境

- iOS 17 以降
- Xcode 16 以降（ビルドする場合）

## ビルド方法

```bash
git clone git@github.com:ChikaraHanakawa/ManholeCardMap.git
```

1. Xcode でプロジェクトを開く
2. ターゲットのデバイス／シミュレータを選択
3. ⌘R で実行

> 経路検索には位置情報の利用許可が必要です。

## プロジェクト構成

```
ManholeCardMap/
├── ManholeCardMapApp.swift   # アプリのエントリポイント
├── Models/                   # データ型の定義（Location, Region など）
├── ViewModels/               # ロジック
│   ├── LocationViewModel.swift             # 状態管理・絞り込み・収集記録
│   ├── LocationViewModel+DataLoading.swift # カードデータの読み込み
│   ├── LocationViewModel+Routing.swift     # 経路計算・純正マップ連携
│   └── LocationViewModel+Location.swift    # 位置情報（GPS）の管理
├── Views/                    # 画面（SwiftUI）
│   ├── ContentView.swift         # メインの地図画面
│   ├── LocationListView.swift    # カード一覧
│   ├── LocationDetailView.swift  # カード詳細
│   └── FilterSheetView.swift     # 絞り込みシート
└── manhole_cards.json        # マンホールカードのデータ
```

## バージョン履歴

| バージョン | 内容 |
|-----------|------|
| v2.0 | データソースを CSV から JSON に移行。絞り込み・収集記録機能を追加。公共交通機関の経路を純正マップ連携に変更。コードを Models / ViewModels / Views に再構成 |
| v1.0 | 初回リリース。CSV ベースの配布場所マップ表示と経路検索 |

## マンホールカードとは

下水道広報プラットホーム（GKP）が発行する、ご当地マンホール蓋のコレクションカードです。全国の配布場所へ実際に足を運ぶことで入手できます。
詳細は [マンホールカード公式サイト](https://www.gk-p.jp/activity/mc/) をご覧ください。

## ライセンス

[MIT License](LICENSE)
