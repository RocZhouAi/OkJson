//  UpdateService.swift
//  OkJson
//
//  基于 GitHub Releases 的自动更新服务

import AppKit

final class UpdateService {

    static let shared = UpdateService()

    private let repoOwner = "RocZhouAi"
    private let repoName = "OkJson"

    // MARK: - 数据模型

    private struct GitHubRelease {
        let version: String
        let tagName: String
        let body: String
        let htmlURL: String
        let zipAssetURL: String?
    }

    // MARK: - 检查更新

    /// 检查更新。silent=true 时无更新不弹窗
    func checkForUpdates(silent: Bool = true) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                if !silent {
                    DispatchQueue.main.async { self.showErrorAlert("无法获取更新信息") }
                }
                return
            }

            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let currentVersion = self.currentAppVersion()

            guard self.isNewer(version, than: currentVersion) else {
                if !silent {
                    DispatchQueue.main.async { self.showUpToDateAlert() }
                }
                return
            }

            // 查找 ZIP 下载地址
            var zipURL: String?
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.hasSuffix(".zip"),
                       let url = asset["browser_download_url"] as? String {
                        zipURL = url
                        break
                    }
                }
            }

            let release = GitHubRelease(
                version: version,
                tagName: tagName,
                body: json["body"] as? String ?? "",
                htmlURL: json["html_url"] as? String ?? "",
                zipAssetURL: zipURL
            )

            DispatchQueue.main.async {
                self.showUpdateAvailableAlert(release)
            }
        }.resume()
    }

    // MARK: - 版本比较

    private func currentAppVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Constants.appVersion
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    // MARK: - 弹窗

    private func showUpdateAvailableAlert(_ release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(release.version)"
        alert.informativeText = "当前版本：v\(currentAppVersion())\n\n\(release.body)"
        alert.alertStyle = .informational

        if release.zipAssetURL != nil {
            alert.addButton(withTitle: "下载并安装")
            alert.addButton(withTitle: "前往下载页")
            alert.addButton(withTitle: "稍后提醒")
        } else {
            alert.addButton(withTitle: "前往下载页")
            alert.addButton(withTitle: "稍后提醒")
        }

        let response = alert.runModal()

        if release.zipAssetURL != nil {
            switch response {
            case .alertFirstButtonReturn:
                downloadAndInstall(from: release.zipAssetURL!)
            case .alertSecondButtonReturn:
                if let url = URL(string: release.htmlURL) {
                    NSWorkspace.shared.open(url)
                }
            default: break
            }
        } else {
            if response == .alertFirstButtonReturn, let url = URL(string: release.htmlURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本 v\(currentAppVersion()) 已经是最新的了。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    // MARK: - 下载并安装

    private func downloadAndInstall(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        // 进度窗口
        let progressWindow = createProgressWindow()
        progressWindow.makeKeyAndOrderFront(nil)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OkJsonUpdate-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let zipPath = tempDir.appendingPathComponent("OkJson.zip")

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            DispatchQueue.main.async { progressWindow.close() }

            guard let self = self, let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async {
                    self?.showErrorAlert("下载失败：\(error?.localizedDescription ?? "未知错误")")
                }
                return
            }

            do {
                try FileManager.default.moveItem(at: tempURL, to: zipPath)
                self.performInstall(zipPath: zipPath, tempDir: tempDir)
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert("安装失败：\(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    private func performInstall(zipPath: URL, tempDir: URL) {
        // 解压
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", zipPath.path, "-d", tempDir.path]
        unzip.standardOutput = FileHandle.nullDevice
        unzip.standardError = FileHandle.nullDevice
        do {
            try unzip.run()
            unzip.waitUntilExit()
        } catch {
            DispatchQueue.main.async { self.showErrorAlert("解压失败") }
            return
        }

        guard unzip.terminationStatus == 0 else {
            DispatchQueue.main.async { self.showErrorAlert("解压失败") }
            return
        }

        // 查找 .app
        guard let newAppPath = findApp(in: tempDir) else {
            DispatchQueue.main.async { self.showErrorAlert("更新包中未找到应用程序") }
            return
        }

        guard let currentAppPath = currentAppBundlePath() else {
            DispatchQueue.main.async { self.showErrorAlert("无法确定当前应用路径") }
            return
        }

        // 写更新脚本：等待当前进程退出 → 替换 → 重新启动
        let scriptPath = tempDir.appendingPathComponent("update.sh")
        let script = """
        #!/bin/bash
        # 等待当前进程退出
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
            sleep 0.2
        done
        # 替换应用
        rm -rf "\(currentAppPath)"
        cp -R "\(newAppPath)" "\(currentAppPath)"
        # 重新启动
        open "\(currentAppPath)"
        # 清理临时文件
        rm -rf "\(tempDir.path)"
        """

        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            DispatchQueue.main.async { self.showErrorAlert("准备更新脚本失败") }
            return
        }

        // 赋予执行权限
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", scriptPath.path]
        try? chmod.run()
        chmod.waitUntilExit()

        // 启动更新脚本并退出应用
        DispatchQueue.main.async {
            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
            launcher.arguments = [scriptPath.path]
            launcher.standardOutput = FileHandle.nullDevice
            launcher.standardError = FileHandle.nullDevice
            try? launcher.run()

            NSApp.terminate(nil)
        }
    }

    // MARK: - 辅助方法

    private func findApp(in directory: URL) -> String? {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return nil
        }
        for item in items {
            if item.hasSuffix(".app") {
                return directory.appendingPathComponent(item).path
            }
        }
        // 可能在子目录中
        for item in items {
            let subDir = directory.appendingPathComponent(item)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: subDir.path, isDirectory: &isDir), isDir.boolValue {
                if let found = findApp(in: subDir) {
                    return found
                }
            }
        }
        return nil
    }

    private func currentAppBundlePath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        // 确保是 .app 包
        guard bundlePath.hasSuffix(".app") else { return nil }
        return bundlePath
    }

    private func createProgressWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "正在下载更新…"
        window.center()

        let progress = NSProgressIndicator(frame: NSRect(x: 20, y: 30, width: 260, height: 20))
        progress.isIndeterminate = true
        progress.style = .bar
        progress.startAnimation(nil)

        let label = NSTextField(labelWithString: "正在下载，请稍候…")
        label.frame = NSRect(x: 20, y: 8, width: 260, height: 18)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        contentView.addSubview(progress)
        contentView.addSubview(label)
        window.contentView = contentView

        return window
    }
}
