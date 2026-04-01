import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var sleepEnabled = true
    private let pmsetHelper = PmsetHelper()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "bed.double", accessibilityDescription: "Sleep") {
                button.image = image
            }
            button.action = #selector(toggleMenu)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        updateMenu()
        checkCurrentState()
    }
    
    @objc func toggleMenu() {
        updateMenu()
        statusItem?.button?.performClick(nil)
    }
    
    private func updateMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleSleep), keyEquivalent: "")
        enabledItem.state = sleepEnabled ? NSControl.StateValue.off : NSControl.StateValue.on
        menu.addItem(enabledItem)
        
        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = isLaunchAtLoginEnabled() ? NSControl.StateValue.on : NSControl.StateValue.off
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleSleep() {
        if sleepEnabled {
            _ = pmsetHelper.runPmsetCommand(disableSleep: true)
            sleepEnabled = false
        } else {
            _ = pmsetHelper.runPmsetCommand(disableSleep: false)
            sleepEnabled = true
        }
        
        updateMenu()
    }
    
    @objc private func toggleLaunchAtLogin() {
        let isEnabled = !isLaunchAtLoginEnabled()
        setLaunchAtLogin(enabled: isEnabled)
        updateMenu()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func checkCurrentState() {
        if let output = pmsetHelper.runCommand("/usr/bin/pmset", arguments: ["-g"]) {
            sleepEnabled = !output.contains("disablesleep 1")
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.sleeper.app.plist")
        return FileManager.default.fileExists(atPath: plistPath.path)
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        let plistName = "com.sleeper.app.plist"
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(plistName)")
        
        if enabled {
            let bundleURL = Bundle.main.bundleURL
            let appPath = bundleURL.path
            
            let plistDict: [String: Any] = [
                "Label": "com.sleeper.app",
                "ProgramArguments": [appPath],
                "RunAtLoad": true,
                "KeepAlive": false
            ]
            
            do {
                let plistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
                try plistData.write(to: plistPath)
                _ = pmsetHelper.runCommand("/bin/launchctl", arguments: ["load", plistPath.path])
            } catch {
                print("Failed to enable launch at login: \(error)")
            }
        } else {
            _ = pmsetHelper.runCommand("/bin/launchctl", arguments: ["unload", plistPath.path])
            try? FileManager.default.removeItem(at: plistPath)
        }
    }
}

class PmsetHelper {
    func runPmsetCommand(disableSleep: Bool) -> Bool {
        let command = disableSleep ? "sudo pmset -a disablesleep 1" : "sudo pmset -a disablesleep 0"
        return runCommandWithSudo(command: command)
    }
    
    func runCommandWithSudo(command: String) -> Bool {
        let script = """
        do shell script "\(command)" with administrator privileges
        """
        return runAppleScript(script: script)
    }
    
    func runCommand(_ command: String, arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func runAppleScript(script: String) -> Bool {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()