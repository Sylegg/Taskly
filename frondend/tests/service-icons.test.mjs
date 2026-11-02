import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { serviceIconPresets } from '../src/lib/service-icons.mjs';
import { resolveServiceIconKey, serviceIconProxyUrl, validateServiceIconFile } from '../src/lib/service-icons.mjs';

test('every preset uses identical image bytes in Admin and Customer', async () => {
  for (const { key } of serviceIconPresets) {
    const web = await readFile(new URL('../public/service-icons/' + key + '.png', import.meta.url));
    const app = await readFile(new URL('../../Taskly-main/assets/service-icons/' + key + '.png', import.meta.url));
    assert.deepEqual(web, app, key);
  }
});

test('admin image previews accept only the known internal immutable icon endpoint', () => {
  const id = '1f090da0-f04c-4ec0-a907-9e7829e2cac7', hash = 'a'.repeat(64);
  const path = `/api/v1/public/service-icons/${id}/${hash}.png`;
  assert.equal(serviceIconProxyUrl(path), `/api/public/service-icons/${id}/${hash}.png`);
  for (const invalid of [null, undefined, '', 'https://example.com' + path, '//example.com' + path,
    path + '?url=http://localhost', path + '/../../customers', path.replace(hash, 'abc'),
    path.replace('.png', '.jpg'), path.replace(id, '..'), '/api/v1/admin/services/' + id]) {
    assert.equal(serviceIconProxyUrl(invalid), null);
  }
});

test('an explicit preset takes priority and automatic selection follows the service slug', () => {
  assert.equal(resolveServiceIconKey('pets', 'home-cleaning'), 'pets');
  assert.equal(resolveServiceIconKey('', 'home-cleaning'), 'cleaning');
  assert.equal(resolveServiceIconKey(null, 'sofa-cleaning'), 'sofa');
  assert.equal(resolveServiceIconKey(undefined, 'wifi-setup'), 'wifi');
  assert.equal(resolveServiceIconKey('invalid', 'unknown-service'), 'grid');
  assert.equal(resolveServiceIconKey(null, 'constructor'), 'grid');
});

test('uploads allow PNG/JPEG up to 1 MiB and reject empty files or other formats', () => {
  for (const type of ['image/png', 'image/jpeg']) {
    assert.equal(validateServiceIconFile({ type, size: 1024 * 1024 }), null);
    assert.ok(validateServiceIconFile({ type, size: 1024 * 1024 + 1 }));
    assert.ok(validateServiceIconFile({ type, size: 0 }));
  }
  for (const type of ['image/svg+xml', 'image/gif', 'image/webp', 'text/plain', '']) {
    assert.ok(validateServiceIconFile({ type, size: 100 }));
  }
});
