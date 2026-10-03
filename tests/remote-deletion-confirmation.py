#!/usr/bin/env python3
"""Run the production confirmation helper with UIKit spies; no remote sends."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'LoopFollow/Views/Treatments/TreatmentsTableView+RemoteDeletion.swift').read_text()
helper = source[source.index('    func confirmPendingRemoteDeletion'):source.index('    // MARK:')]
fixture = r'''
import Foundation
class UIAlertAction {
    enum Style { case destructive, cancel }
    let title: String?
    let style: Style
    let handler: ((UIAlertAction) -> Void)?
    init(title: String?, style: Style, handler: ((UIAlertAction) -> Void)?) {
        self.title = title; self.style = style; self.handler = handler
    }
    func tap() { handler?(self) }
}
class UIAlertController {
    enum Style { case alert }
    let title: String?
    var actions: [UIAlertAction] = []
    init(title: String?, message: String?, preferredStyle: Style) { self.title = title }
    func addAction(_ action: UIAlertAction) { actions.append(action) }
    func dismiss(animated: Bool, completion: (() -> Void)?) { completion?() }
}
class TreatmentsTableView {
    var presented: UIAlertController?
    func present(_ alert: UIAlertController, animated: Bool) { presented = alert }
    HELPER
}
@main struct Tests {
    static func main() {
        let tracker = RemoteCommandReceiptTracker.shared
        let controller = TreatmentsTableView()
        var sent = 0
        var cancelled = 0
        let send = { sent += 1 }
        let cancel = { cancelled += 1 }
        controller.confirmPendingRemoteDeletion(send: send, onCancel: cancel)
        precondition(sent == 1 && controller.presented == nil)
        let message = PushMessage(aps: .init(alert: ""), user: "test", commandType: .meal,
                                  carbs: 3, sharedSecret: "", timestamp: Date().timeIntervalSince1970)
        tracker.track(message, id: "first", site: "test")
        controller.confirmPendingRemoteDeletion(send: send, onCancel: cancel)
        let alert = controller.presented!
        precondition(alert.title == "Remote kommando pågår" && sent == 1)
        precondition(alert.actions[0].title == "Skicka ändå" && alert.actions[0].style == .destructive)
        precondition(alert.actions[1].title == "Avbryt" && alert.actions[1].style == .cancel)
        alert.actions[1].tap()
        precondition(cancelled == 1 && sent == 1 && tracker.hasPendingCommands)
        controller.confirmPendingRemoteDeletion(send: send, onCancel: cancel)
        controller.presented!.actions[0].tap()
        precondition(sent == 2 && !tracker.hasPendingCommands)
        print("Remote deletion confirmation passed: no blocker, cancellation, destructive override before 30 seconds")
    }
}
'''.replace('    HELPER', helper)
with tempfile.TemporaryDirectory(prefix='remote-deletion-') as tmp:
    path = Path(tmp)
    (path / 'main.swift').write_text(fixture)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', '/tmp/remote-receipt-module-cache',
        str(root / 'LoopFollow/Remote/TRC/TRCCommandType.swift'), str(root / 'LoopFollow/Remote/PushMessage.swift'),
        str(root / 'LoopFollow/Remote/RemoteCommandReceiptTracker.swift'), str(path / 'main.swift'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
