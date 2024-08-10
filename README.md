# SQLite Extension Sample

This sample is used as a fixture for testing the SQLite extension in the Node.js source code.

## Usage

```shell
make loadable
```

```js
const {DatabaseSync} = require('node:sqlite');
const db = new DatabaseSync(dbPath, {allowLoadExtension: true});
db.loadExtension('./dist/sample');
const {noop} = db.prepare(
    'select noop(1) as noop;'
).get();
console.log(noop);  // 1
```

### Reference

- [SQLite Extension](https://www.sqlite.org/loadext.html)
- [SQLite Extension Noop Sample](https://www.sqlite.org/src/info/f1a21cc9b7a4e667e5c8458d80ba680b8bd4315a003f256006046879f679c5a0)
- [Original Makefile](https://github.com/asg017/sqlite-vec/blob/a6498d04b816c29f6a5c807da1c9e1993780444c/Makefile)
