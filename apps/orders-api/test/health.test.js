const test = require('node:test');
const assert = require('node:assert');
const server = require('../src/server');
test('health', async () => {
  await new Promise(r => server.listen(0, r));
  const res = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  assert.strictEqual(res.status, 200);
  server.close();
});
