import Foundation
import AppKit
import Observation

@Observable
final class AppModel {
    var jobs: [DownloadJob] = []
    var urlText = ""
    /// 見つかったツール。nil なら未インストール
    var ytdlp: URL?
    var ffmpeg: URL?
    var ytdlpVersion: String?

    private var downloader: Downloader?
    private var current: DownloadJob?

    init() {
        Prefs.registerDefaults()
        refreshTools()
    }

    // MARK: 設定の読み出し

    var folder: URL {
        URL(fileURLWithPath: UserDefaults.standard.string(forKey: Prefs.folder) ?? Prefs.defaultFolder.path, isDirectory: true)
    }
    var format: AudioFormat {
        AudioFormat(rawValue: UserDefaults.standard.string(forKey: Prefs.format) ?? "") ?? .m4a
    }
    var isBusy: Bool { current != nil }
    var toolsReady: Bool { ytdlp != nil && ffmpeg != nil }

    func refreshTools() {
        let d = UserDefaults.standard
        ytdlp = Tools.locate("yt-dlp", override: d.string(forKey: Prefs.ytdlpPath) ?? "")
        ffmpeg = Tools.locate("ffmpeg", override: d.string(forKey: Prefs.ffmpegPath) ?? "")
        ytdlpVersion = nil
        if let y = ytdlp {
            DispatchQueue.global().async {
                let r = Tools.run(y, ["--version"])
                DispatchQueue.main.async { self.ytdlpVersion = r.status == 0 ? r.output : nil }
            }
        }
    }

    // MARK: URL の追加

    /// 入力欄のテキストから URL を拾って追加（複数行・空白区切りも可）
    func addFromText() {
        let urls = Self.extractURLs(from: urlText)
        if urls.isEmpty { return }
        urlText = ""
        for u in urls { enqueue(u) }
    }

    func addFromClipboard() {
        guard let s = NSPasteboard.general.string(forType: .string) else { return }
        for u in Self.extractURLs(from: s) { enqueue(u) }
    }

    func add(urls: [String]) {
        for u in urls { for x in Self.extractURLs(from: u) { enqueue(x) } }
    }

    static func extractURLs(from text: String) -> [String] {
        var found: [String] = []
        for raw in text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) {
            var s = String(raw)
            if !s.contains("://") {
                if s.hasPrefix("youtu.be/") || s.hasPrefix("www.youtube.com/") || s.hasPrefix("youtube.com/") || s.hasPrefix("music.youtube.com/") {
                    s = "https://" + s
                } else { continue }
            }
            if URL(string: s) != nil, !found.contains(s) { found.append(s) }
        }
        return found
    }

    private func enqueue(_ url: String) {
        if jobs.contains(where: { $0.url == url && $0.isActive }) { return }
        jobs.insert(DownloadJob(url: url), at: 0)   // 新しいものを上に
        pump()
    }

    // MARK: 実行（1 件ずつ）

    private func pump() {
        guard current == nil, toolsReady, let ytdlp, let ffmpeg else { return }
        // 一覧は新しい順なので、いちばん下（先に追加したもの）から処理する
        guard let job = jobs.last(where: { $0.state == .waiting }) else { return }
        let d = UserDefaults.standard
        let folder = self.folder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            job.state = .failed("保存先フォルダを作れません: \(folder.path)")
            pump()
            return
        }
        let opts = Downloader.Options(
            folder: folder,
            format: format,
            squareCover: d.bool(forKey: Prefs.squareCover),
            wholePlaylist: d.bool(forKey: Prefs.wholePlaylist),
            idInFilename: d.bool(forKey: Prefs.idInFilename),
            ytdlp: ytdlp,
            ffmpegDir: ffmpeg.deletingLastPathComponent())
        let dl = Downloader()
        downloader = dl
        current = job
        job.state = .running("準備中")
        dl.start(job: job, options: opts) { [weak self] error in
            guard let self else { return }
            if let error {
                job.state = (error == "中止") ? .cancelled : .failed(error)
            } else if job.files.isEmpty {
                job.state = .failed("ファイルができませんでした")
            } else {
                self.finish(job)
                job.state = .done
            }
            self.current = nil
            self.downloader = nil
            self.pump()
        }
    }

    /// できあがったファイルごとに、カバー画像を Finder アイコンにして、jpg を片づける
    private func finish(_ job: DownloadJob) {
        let d = UserDefaults.standard
        let setIcon = d.bool(forKey: Prefs.setFinderIcon)
        let keep = d.bool(forKey: Prefs.keepThumbnail)
        for file in job.files {
            guard let thumb = CoverArt.thumbnailURL(for: file) else { continue }
            if let img = NSImage(contentsOf: thumb) {
                if job.thumbnail == nil { job.thumbnail = img }
                if setIcon { CoverArt.applyFinderIcon(image: img, to: file) }
            }
            if !keep { try? FileManager.default.removeItem(at: thumb) }
        }
    }

    func cancel(_ job: DownloadJob) {
        if job === current {
            downloader?.cancel()
        } else if job.state == .waiting {
            job.state = .cancelled
        }
    }

    func cancelAll() {
        for j in jobs where j.state == .waiting { j.state = .cancelled }
        downloader?.cancel()
    }

    func retry(_ job: DownloadJob) {
        guard !job.isActive else { return }
        job.state = .waiting
        job.progress = 0
        job.files = []
        job.log = []
        pump()
    }

    func remove(_ job: DownloadJob) {
        if job.isActive { cancel(job) }
        jobs.removeAll { $0 === job }
    }

    func clearFinished() {
        jobs.removeAll { !$0.isActive }
    }

    // MARK: Finder

    func reveal(_ job: DownloadJob) {
        if job.files.isEmpty { revealFolder() } else { NSWorkspace.shared.activateFileViewerSelecting(job.files) }
    }

    func revealFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "この場所に保存"
        panel.directoryURL = folder
        if panel.runModal() == .OK, let u = panel.url {
            UserDefaults.standard.set(u.path, forKey: Prefs.folder)
        }
    }
}
