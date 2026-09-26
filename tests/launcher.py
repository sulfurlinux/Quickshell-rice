"""Run: python tests/launcher.py (requires PySide6).

Test the actual launcher UI with an Item host and inert process stubs.
Wayland focus and physical monitor scaling still need a Hyprland session.
"""
import json
import os
from pathlib import Path
import re
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QPoint, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

repo = Path(__file__).resolve().parents[1]
app = QGuiApplication([])

with tempfile.TemporaryDirectory() as directory:
    fixture = Path(directory)
    (fixture / "Process.qml").write_text("""import QtQuick
QtObject {
    property var command: []
    property bool running: false
    property QtObject stdout
}
""", encoding="utf-8")
    (fixture / "SplitParser.qml").write_text("""import QtQuick
QtObject { signal read(string data) }
""", encoding="utf-8")
    source = (repo / "quickshell/modules/Launcher.qml").read_text(encoding="utf-8")
    source = re.sub(r"^import Quickshell.*\n", "", source, flags=re.MULTILINE)
    source = source.replace("PanelWindow {", "Item {", 1)
    source = re.sub(r"^    WlrLayershell\..*\n", "", source, flags=re.MULTILINE)
    source = re.sub(r"^    exclusionMode:.*\n", "", source, flags=re.MULTILINE)
    source = re.sub(r"    anchors \{\s*top: true\s*bottom: true\s*left: true\s*right: true\s*\}", "", source, count=1)
    source = source.replace('    color: "transparent"', "", 1)
    source = source.replace("    id: root", """    id: root
    property var screen
    QtObject { id: testHyprland; property var focusedMonitor: null }
    QtObject { id: testQuickshell; property var screens: [] }
""", 1)
    source = source.replace("Hyprland.focusedMonitor", "testHyprland.focusedMonitor")
    source = source.replace("Quickshell.screens", "testQuickshell.screens")
    (fixture / "Launcher.qml").write_text(source, encoding="utf-8")

    view = QQuickView()
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(1000, 800)
    view.setSource(QUrl.fromLocalFile(str(fixture / "Launcher.qml")))
    assert view.status() == QQuickView.Ready, [error.toString() for error in view.errors()]
    root = view.rootObject()
    context = QQmlEngine.contextForObject(root)

    def evaluate(expression):
        script = QQmlExpression(context, root, expression)
        result, _ = script.evaluate()
        assert not script.hasError(), script.error().toString()
        return result.toVariant() if hasattr(result, "toVariant") else result

    def settle():
        QTest.qWait(30)

    apps = [{"name": f"App {index:02}", "exec": f"test-app-{index}"} for index in range(40)]
    evaluate(f"root.allApps = {json.dumps(apps)}; root.visible = true; root.filterApps()")
    view.show()
    settle()
    assert evaluate("appList.count") == 40
    assert evaluate("searchInput.activeFocus")
    # Park the cursor over a result, then navigate and rebuild results.
    point = evaluate("appList.mapToItem(root, 40, 60)")
    QTest.mouseMove(view, QPoint(int(point.x()), int(point.y())))
    QTest.keyClick(view, Qt.Key_Down)
    settle()
    assert evaluate("appList.currentIndex") == 1
    for _ in range(20):
        QTest.keyClick(view, Qt.Key_Down)
    settle()
    assert evaluate("appList.currentIndex") == 21
    assert evaluate("appList.contentY > 0")
    evaluate("searchInput.text = 'App 0'")
    settle()
    assert evaluate("appList.currentIndex") == 0
    assert evaluate("appList.contentY === appList.originY")
    evaluate("searchInput.text = 'no matching app'")
    assert evaluate("appList.count") == 0
    assert evaluate("appList.currentIndex") == -1
    assert evaluate("launcherCard.height") == 74
    QTest.keyClick(view, Qt.Key_Down)
    assert evaluate("appList.currentIndex") == -1
    print("PASS: stationary cursor, keyboard navigation, scrolling, search reset, empty results")

    evaluate("searchInput.text = '/wallpaper'")
    evaluate("searchInput.text = 'App 01'")
    wallpaper = [{"name": "forest.png", "path": "", "exec": "wallpaper_select:/forest.png"}]
    evaluate(f"acceptWallpapers({json.dumps(json.dumps(wallpaper))})")
    assert evaluate("appListModel.get(0).name") == "App 01"
    assert evaluate("launcherCard.height") == 126
    evaluate("searchInput.text = '/wallpaper forest'")
    assert evaluate("appList.count") == 1
    assert evaluate("appListModel.get(0).name") == "forest.png"
    evaluate("searchInput.text = '/wallpaper nonexistent'")
    assert evaluate("appList.count") == 0
    print("PASS: delayed wallpaper response preserves app search; empty space shrinks with results")

    evaluate("searchInput.text = ''; root.filterApps()")
    for width, height in [(1920, 1080), (1280, 720), (640, 360), (320, 240)]:
        view.resize(width, height)
        settle()
        assert evaluate("launcherCard.width") == min(540, width - 32)
        assert evaluate("launcherCard.height") == min(460, height - 32)
        assert evaluate("appList.width > 0 && appList.height > 0")
        assert evaluate("appList.x + appList.width <= launcherCard.width")
    print("PASS: launcher fits logical screen sizes from 320x240 to 1920x1080")

    evaluate("testQuickshell.screens = [{name: 'DP-1'}, {name: 'HDMI-A-1'}]")
    evaluate("testHyprland.focusedMonitor = {name: 'HDMI-A-1'}; focusScreen()")
    assert evaluate("screen.name") == "HDMI-A-1"
    evaluate("testHyprland.focusedMonitor = {name: 'DP-1'}")
    assert evaluate("screen.name") == "HDMI-A-1"
    evaluate("focusScreen()")
    assert evaluate("screen.name") == "DP-1"
    print("PASS: focused output chosen on opening; focus changes do not move an open launcher")

    evaluate("searchInput.text = 'App 01'; visible = true")
    QTest.keyClick(view, Qt.Key_Return)
    settle()
    assert not evaluate("visible")
    assert evaluate("execProcess.running")
    evaluate("visible = true")
    settle()
    QTest.keyClick(view, Qt.Key_Escape)
    assert not evaluate("visible")
    print("PASS: Enter launches the selected row and Escape dismisses the launcher")
    view.close()
