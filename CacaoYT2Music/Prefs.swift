import Foundation

/// 設定の保存キー。画面（@AppStorage）とモデル（UserDefaults）で同じキーを使う。
enum Prefs {
    static let folder = "saveFolder"               // 保存先フォルダのパス
    static let format = "audioFormat"              // m4a / mp3
    static let setFinderIcon = "setFinderIcon"     // 保存したファイルの Finder アイコンにカバー画像を使う
    static let squareCover = "squareCover"         // カバー画像を正方形に切り抜く
    static let keepThumbnail = "keepThumbnail"     // カバー画像（jpg）もファイルとして残す
    static let wholePlaylist = "wholePlaylist"     // 再生リストの URL なら全曲
    static let idInFilename = "idInFilename"       // ファイル名に動画 ID を付ける（同名曲の衝突よけ）
    static let ytdlpPath = "ytdlpPath"             // 空なら自動検出
    static let ffmpegPath = "ffmpegPath"           // 空なら自動検出

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            folder: defaultFolder.path,
            format: AudioFormat.m4a.rawValue,
            setFinderIcon: true,
            squareCover: true,
            keepThumbnail: false,
            wholePlaylist: false,
            idInFilename: false,
            ytdlpPath: "",
            ffmpegPath: "",
        ])
    }

    static var defaultFolder: URL {
        FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
            .appendingPathComponent("YouTube", isDirectory: true)
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case m4a, mp3
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var note: String {
        switch self {
        case .m4a: return "元の音声をそのまま（劣化なし・おすすめ）"
        case .mp3: return "変換して保存（対応機器が多い）"
        }
    }
}
