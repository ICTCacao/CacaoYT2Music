# CacaoYT2Music

YouTube の URL を貼り付けると、音声だけを **m4a（または mp3）** にして保存する Mac アプリ。
カバーやアレンジ曲を自分で聴くための道具。実作業は Homebrew の `yt-dlp` と `ffmpeg` に任せている。

| できること | 中身 |
|---|---|
| URL → m4a | 元の AAC 音声をそのまま取り出す（劣化なし） |
| URL → mp3 | 最高品質（VBR）に変換 |
| 曲情報 | タイトル・チャンネル名を埋め込む |
| カバー画像 | YouTube のサムネイル（16:9）を、幅はそのまま上下をぼかしで埋めて正方形にして埋め込む。保存したファイルの **Finder アイコン** にも使う |
| まとめて | 複数 URL・再生リスト（設定で全曲）・ドラッグ＆ドロップ・クリップボード（⇧⌘V） |

## 入手

[Releases](https://github.com/ICTCacao/CacaoYT2Music/releases) から `CacaoYT2Music-<version>.dmg` を落とし、
中のアプリを Applications へドラッグする。署名していないので、初回は Applications 内のアプリを
右クリック →「開く」で起動する（macOS 14 以降）。

## 必要なもの

macOS 14 以降と、Homebrew の yt-dlp / ffmpeg。

```bash
brew install yt-dlp ffmpeg
```

YouTube 側の変更で保存できなくなったら、設定画面の「yt-dlp を更新」（`brew upgrade yt-dlp`）。

## 使い方

1. URL を貼って Return（または「追加」）。クリップボードに URL があれば ⇧⌘V でも追加できる。
2. 保存先は既定で `~/Music/YouTube`。「変更…」で好きな場所に。
3. できたら行の 🔍 で Finder に表示、▶ で再生。ミュージックのライブラリに入れるなら m4a をドラッグするだけ。

URL を追加した直後に yt-dlp で題名・チャンネル名・サムネイルだけ軽く取ってきて（1〜2 秒）、
待機中の行にも題名を出す。本番の保存が終わると、埋め込んだカバー画像に置き換わる。

再生リストの中に見られない動画（非公開・削除など）があっても、その曲だけ飛ばして残りを保存し、
行に「N 曲は保存できず」と出す。途中で失敗して jpg が保存先に残ったときは、ファイルメニューの
「保存先に残ったカバー画像（jpg）を片づける」で Finder アイコンに設定して消せる。

設定（⌘,）で、Finder アイコンにカバーを使うか、正方形のしかた（上下を埋める／切り抜く／そのまま）、jpg も残すか、再生リストを全曲にするか、
ファイル名に動画 ID を付けるか、yt-dlp / ffmpeg の場所を変えられる。

## 構成

```
CacaoYT2Music/
├── project.yml                    # XcodeGen の定義（ここから .xcodeproj を生成）
├── CacaoYT2Music.xcodeproj        # 生成物（xcodegen generate で再生成できる）
├── bump-version.sh                # 配布用ビルドの前に 0.0.1 上げる
├── make-dmg.sh                    # 配布用 dmg を作る（背景は dmg/make-background.swift で生成）
├── icon/make-icon.swift           # アプリアイコンを描くスクリプト
├── dist/                          # ビルド済み: *.app / *.dmg
└── CacaoYT2Music/                 # Mac アプリ（SwiftUI）
    ├── CacaoYT2MusicApp.swift     # エントリ・メニュー
    ├── AppModel.swift             # キュー（1 件ずつ実行）・設定・Finder
    ├── Downloader.swift           # yt-dlp を起動し、出力を読んで進み具合に変える
    ├── CoverArt.swift             # 同名の jpg を Finder アイコンにする
    ├── Tools.swift                # yt-dlp / ffmpeg / brew の場所探し
    ├── Prefs.swift                # 設定キーと既定値
    └── Views/                     # 画面・設定
```

### yt-dlp に渡しているもの

```
-x --audio-format m4a|mp3 [--audio-quality 0]
--embed-metadata --embed-thumbnail --write-thumbnail --convert-thumbnails jpg
--ppa "ThumbnailsConvertor+ffmpeg_o:-c:v mjpeg -vf ..."        # 正方形にする（上下をぼかしで埋める／切り抜く／なし）
--print before_dl:TITLE / UPLOADER、after_move:FILE          # 画面に出す題名とできたファイルの場所
--no-playlist | --yes-playlist
-o <保存先>/%(title)s.%(ext)s
```

`--write-thumbnail` で残った jpg を Finder アイコンに使い、使い終わったら消す（設定で残せる）。

## ビルド

必要: Xcode、XcodeGen（`brew install xcodegen`）。

```bash
cd ~/CacaoApps/CacaoYT2Music
./bump-version.sh                         # 配布用ビルドのたびにバージョンを 0.0.1 上げる
xcodegen generate                         # project.yml を変えたときだけ
xcodebuild -project CacaoYT2Music.xcodeproj -scheme CacaoYT2Music -configuration Release \
  -derivedDataPath build/DerivedData build
rm -rf dist/CacaoYT2Music.app && cp -R build/DerivedData/Build/Products/Release/CacaoYT2Music.app dist/
./make-dmg.sh                             # dist/CacaoYT2Music-<version>.dmg
```

## 使ううえでの注意

- YouTube の利用規約は、公式の手段（YouTube Premium など）以外でのダウンロードを認めていない。自分で聴く範囲にとどめること。
- 違法にアップロードされたものだと知りながら保存するのは、日本の著作権法でも違法。公式チャンネルや演奏者本人の動画に限る。
- 保存した音源を配布する・公開する・人前で流す・公開するアプリに組み込むのは私的使用を超える。

## ライセンス

MIT License（[LICENSE](LICENSE)）。yt-dlp は Unlicense、ffmpeg は LGPL/GPL。どちらもアプリには同梱せず、Homebrew のものを使う。
