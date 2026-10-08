#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const serviceQml = fs.readFileSync(path.join(root, 'shell/plugins/lock/Service.qml'), 'utf8')

assert(
  /property bool sessionLocked: false/.test(serviceQml),
  'the lock service defines a sessionLocked property on root with change notifications'
)

assert(
  /readonly property bool locked: lockRequested \|\| sessionLocked \|\| sessionLock\.secure/.test(serviceQml),
  'the composite locked property binds to sessionLocked instead of WlSessionLock.locked'
)

assert(
  /function requestSessionLock\(\) \{[\s\S]*sessionLocked = true\s*\n\s*sessionLock\.locked = true/.test(serviceQml),
  'requesting the session lock marks sessionLocked true'
)

assert(
  /function finishUnlock\(\) \{[\s\S]*sessionLocked = false\s*[\s\S]*sessionLock\.locked = false/.test(serviceQml),
  'finishing unlock clears sessionLocked before or alongside sessionLock.locked'
)

assert(
  /onLockStateChanged: \{[\s\S]*root\.sessionLocked = locked/.test(serviceQml),
  'lock state changes synchronize root.sessionLocked'
)

assert(
  /status\(\): string \{[\s\S]*sessionLocked: root\.sessionLocked/.test(serviceQml),
  'status IPC reports root.sessionLocked so components and composite stay consistent'
)
JS
