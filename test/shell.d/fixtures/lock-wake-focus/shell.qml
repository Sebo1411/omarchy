import QtQuick
import Quickshell
import qs.Commons

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("OMARCHY_QML_TEST_RESULT")
  readonly property string rootPath: Quickshell.env("OMARCHY_PATH")
  property var failures: []

  function fail(message) {
    failures.push(String(message))
  }

  function assertTrue(condition, message) {
    if (!condition) fail(message)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures
    })

    if (resultPath) {
      Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
    }
  }

  Item {
    id: host
    width: 800
    height: 600

    Item {
      id: decoyFocusItem
      focus: true
    }
  }

  Timer {
    interval: 10
    running: true
    repeat: false
    onTriggered: {
      try {
        var component = Qt.createComponent("file://" + root.rootPath + "/shell/plugins/lock/LockView.qml", Component.PreferSynchronous)
        if (component.status !== Component.Ready) {
          root.fail("LockView failed to load: " + component.errorString())
          root.writeResult()
          return
        }

        var view = component.createObject(host, {
          width: 800,
          height: 600,
          loadBackground: false,
          inputEnabled: true,
          displaysBlank: true
        })
        if (!view) {
          root.fail("LockView failed to instantiate: " + component.errorString())
          root.writeResult()
          return
        }

        // Steal focus away from view
        decoyFocusItem.forceActiveFocus()
        root.assertTrue(!view.passwordActiveFocus, "password input loses focus when decoy item grabs it")

        // Now simulate wake/unblank
        view.displaysBlank = false

        // Allow Qt.callLater to execute
        Qt.callLater(function() {
          try {
            root.assertTrue(view.passwordActiveFocus, "password input re-acquires active focus when displays unblank on wake")
          } catch (e) {
            root.fail("assertion failed: " + e)
          } finally {
            view.destroy()
            root.writeResult()
          }
        })
      } catch (error) {
        root.fail("lock wake focus fixture threw: " + error)
        root.writeResult()
      }
    }
  }
}
