#!/usr/bin/env node
/**
 * Генерирует superfile.json для IGS - бандл всех Lua файлов для автообновления
 */
const fs = require('fs');
const path = require('path');

const LUA_DIR = path.join(__dirname, '..', 'lua');
const OUT_FILE = path.join(__dirname, '..', 'superfile.json');

function walkDir(dir, base = '') {
  const result = {};
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const fullPath = path.join(dir, e.name);
    const relPath = base ? base + '/' + e.name : e.name;
    if (e.isDirectory()) {
      Object.assign(result, walkDir(fullPath, relPath));
    } else if (e.name.endsWith('.lua')) {
      result[relPath] = fs.readFileSync(fullPath, 'utf8');
    }
  }
  return result;
}

// Авторун в корне lua
const autorunPath = path.join(LUA_DIR, 'autorun');
if (fs.existsSync(autorunPath)) {
  const autorun = walkDir(autorunPath, 'autorun');
  const igs = walkDir(path.join(LUA_DIR, 'igs'), 'igs');
  const entities = fs.existsSync(path.join(LUA_DIR, 'entities')) 
    ? walkDir(path.join(LUA_DIR, 'entities'), 'entities') : {};
  const superfile = { ...autorun, ...igs, ...entities };
  fs.writeFileSync(OUT_FILE, JSON.stringify(superfile), 'utf8');
  console.log('superfile.json создан:', Object.keys(superfile).length, 'файлов');
} else {
  console.error('Папка lua/autorun не найдена');
  process.exit(1);
}
