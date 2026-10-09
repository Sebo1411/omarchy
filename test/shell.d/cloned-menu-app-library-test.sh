#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const shellQml = fs.readFileSync(path.join(root, 'shell/shell.qml'), 'utf8')

const match = shellQml.match(/function manifestHasKind\(manifest, kind\) \{([\s\S]*?)\n  \}/)
assert(match, 'shell.qml defines manifestHasKind')

const manifestHasKind = new Function('manifest', 'kind', match[1])

// Standard JS Array checks
assert(manifestHasKind({ kinds: ['menu'] }, 'menu') === true, 'manifestHasKind matches kind in JS array')
assert(manifestHasKind({ kinds: ['menu', 'bar-widget'] }, 'bar-widget') === true, 'manifestHasKind matches second kind in JS array')
assert(manifestHasKind({ kinds: ['menu'] }, 'bar') === false, 'manifestHasKind rejects missing kind in JS array')

// Sequence-like objects (e.g. QML V4Sequence wrapping QVariantList from modelData / property var)
class MockV4Sequence {
  constructor(items) {
    this._items = items
  }
  indexOf(kind) {
    return this._items.indexOf(kind)
  }
}

const sequence = new MockV4Sequence(['menu', 'bar-widget'])
assert(!Array.isArray(sequence), 'MockV4Sequence is not a native JS Array')
assert(typeof sequence === 'object', 'MockV4Sequence is an object')
assert(manifestHasKind({ kinds: sequence }, 'menu') === true, 'manifestHasKind matches kind in sequence object')
assert(manifestHasKind({ kinds: sequence }, 'bar-widget') === true, 'manifestHasKind matches second kind in sequence object')
assert(manifestHasKind({ kinds: sequence }, 'panel') === false, 'manifestHasKind rejects missing kind in sequence object')

// Non-object and invalid inputs
assert(manifestHasKind(null, 'menu') === false, 'manifestHasKind rejects null manifest')
assert(manifestHasKind(undefined, 'menu') === false, 'manifestHasKind rejects undefined manifest')
assert(manifestHasKind({}, 'menu') === false, 'manifestHasKind rejects manifest without kinds')
assert(manifestHasKind({ kinds: null }, 'menu') === false, 'manifestHasKind rejects null kinds')
assert(manifestHasKind({ kinds: 'menu' }, 'menu') === false, 'manifestHasKind rejects string kinds')
assert(manifestHasKind({ kinds: 'menu-app' }, 'menu') === false, 'manifestHasKind rejects substring match on string kinds')
assert(manifestHasKind({ kinds: 123 }, 'menu') === false, 'manifestHasKind rejects numeric kinds')
assert(manifestHasKind({ kinds: {} }, 'menu') === false, 'manifestHasKind rejects plain object without indexOf')

// Scoped shell wiring checks
assert(
  shellQml.includes('appLibrary: shell.manifestHasKind(manifest, "menu")'),
  'scoped plugin shell gates appLibrary on manifestHasKind'
)
assert(
  shellQml.includes('shell.manifestHasKind(manifest, "menu") ? "menu" : "no-menu"'),
  'plugin shell capability profile queries manifestHasKind for menu kind'
)
assert(
  shellQml.includes('return shell.manifestHasKind(manifest, "bar")'),
  'isBarOptionManifest delegates to shell.manifestHasKind'
)
JS
