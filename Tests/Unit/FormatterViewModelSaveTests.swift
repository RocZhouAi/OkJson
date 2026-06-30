//  FormatterViewModelSaveTests.swift
//  OkJsonTests
//
//  覆盖 saveToSourceFile 的写回与按标题重命名磁盘文件的各分支

import XCTest
@testable import OkJson

final class FormatterViewModelSaveTests: XCTestCase {

    private var tmpDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OkJsonSaveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir = tmpDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }

    /// 在临时目录创建文件，返回其路径
    private func makeFile(_ name: String, content: String) throws -> String {
        let url = tmpDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    private func makeViewModel(path: String, title: String, content: String) -> FormatterViewModel {
        let vm = FormatterViewModel()
        vm.sourceFilePath = path
        vm.columnTitle = title
        vm.editorTextProvider = { content }
        return vm
    }

    // MARK: - 不改名：仅写回内容

    func testSaveWritesContentWithoutRename() throws {
        let path = try makeFile("data.json", content: "OLD")
        let vm = makeViewModel(path: path, title: "data.json", content: "NEWCONTENT")
        vm.isModifiedSinceFileOpen = true

        try vm.saveToSourceFile()

        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "NEWCONTENT")
        XCTAssertEqual(vm.sourceFilePath, path, "未改名时路径不变")
        XCTAssertFalse(vm.isModifiedSinceFileOpen, "保存后应清除未保存标记")
    }

    // MARK: - 改名：重命名磁盘文件

    func testSaveRenamesFileWhenTitleChanged() throws {
        let oldPath = try makeFile("data.json", content: "ignored")
        let vm = makeViewModel(path: oldPath, title: "renamed.json", content: "BODY")

        try vm.saveToSourceFile()

        let newPath = tmpDir.appendingPathComponent("renamed.json").path
        XCTAssertEqual(vm.sourceFilePath, newPath, "sourceFilePath 应更新为新路径")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldPath), "旧文件应已消失")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath), "新文件应存在")
        XCTAssertEqual(try String(contentsOfFile: newPath, encoding: .utf8), "BODY")
        XCTAssertFalse(vm.isModifiedSinceFileOpen)
    }

    func testSaveAppendsOriginalExtensionWhenMissing() throws {
        let oldPath = try makeFile("data.json", content: "X")
        let vm = makeViewModel(path: oldPath, title: "renamed", content: "X") // 漏写扩展名

        try vm.saveToSourceFile()

        XCTAssertEqual(URL(fileURLWithPath: vm.sourceFilePath ?? "").lastPathComponent, "renamed.json",
                       "漏写扩展名应自动补回原扩展名")
        XCTAssertEqual(vm.columnTitle, "renamed.json", "规范化后的文件名应回填到列标题")
    }

    // MARK: - 失败分支

    func testSaveThrowsWhenTargetExistsAndKeepsSourceIntact() throws {
        _ = try makeFile("other.json", content: "OTHER")
        let srcPath = try makeFile("data.json", content: "ORIGINAL")
        let vm = makeViewModel(path: srcPath, title: "other.json", content: "NEW")

        XCTAssertThrowsError(try vm.saveToSourceFile()) { error in
            guard case FormatterViewModel.SaveError.targetExists = error else {
                return XCTFail("应抛 targetExists，实际：\(error)")
            }
        }
        // 冲突发生在写入之前：源文件内容与自身均不应被破坏
        XCTAssertTrue(FileManager.default.fileExists(atPath: srcPath))
        XCTAssertEqual(try String(contentsOfFile: srcPath, encoding: .utf8), "ORIGINAL",
                       "冲突时不应写入源文件")
    }

    func testSaveThrowsOnInvalidName() throws {
        let path = try makeFile("data.json", content: "X")

        let blank = makeViewModel(path: path, title: "   ", content: "X")
        XCTAssertThrowsError(try blank.saveToSourceFile()) { error in
            guard case FormatterViewModel.SaveError.invalidFileName = error else {
                return XCTFail("空标题应抛 invalidFileName，实际：\(error)")
            }
        }

        let slash = makeViewModel(path: path, title: "a/b.json", content: "X")
        XCTAssertThrowsError(try slash.saveToSourceFile()) { error in
            guard case FormatterViewModel.SaveError.invalidFileName = error else {
                return XCTFail("含「/」应抛 invalidFileName，实际：\(error)")
            }
        }
    }

    func testSaveThrowsWhenNoSourceFile() {
        let vm = FormatterViewModel()
        vm.sourceFilePath = nil
        XCTAssertThrowsError(try vm.saveToSourceFile()) { error in
            guard case FormatterViewModel.SaveError.noSourceFile = error else {
                return XCTFail("无关联文件应抛 noSourceFile，实际：\(error)")
            }
        }
    }
}
