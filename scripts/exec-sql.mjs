import fs from 'node:fs';
import mysql from 'mysql2/promise';

// Usage:
//   node scripts/exec-sql.mjs database_migration_xxx.sql
const sqlFile = process.argv[2];
if (!sqlFile) {
  console.error('Fichier SQL requis: node scripts/exec-sql.mjs <file.sql>');
  process.exit(1);
}

const filePath = sqlFile.startsWith('C:\\') || sqlFile.startsWith('/')
  ? sqlFile
  : `./${sqlFile}`;

const sqlText = fs.readFileSync(filePath, 'utf8');

// Parsing simple mais robuste pour gérer DELIMITER (triggers/procedures).
let delimiter = ';';
let buffer = '';
const statements = [];

const lines = sqlText.split(/\r?\n/);
for (const lineRaw of lines) {
  const line = lineRaw.trimEnd();

  // Detect DELIMITER <token>
  const delimMatch = line.match(/^DELIMITER\s+(.+)\s*$/i);
  if (delimMatch) {
    delimiter = delimMatch[1].trim();
    continue;
  }

  // Accumulation
  buffer += line + '\n';

  // If current buffer ends with delimiter token, flush
  if (delimiter !== ';') {
    const trimmed = buffer.trimEnd();
    if (trimmed.endsWith(delimiter)) {
      const stmt = trimmed.slice(0, trimmed.length - delimiter.length).trim();
      if (stmt) statements.push(stmt);
      buffer = '';
    }
    continue;
  }

  // delimiter == ';' -> usual case: flush on last non-empty char
  if (delimiter === ';') {
    const trimmed = buffer.trimEnd();
    if (trimmed.endsWith(';')) {
      const stmt = trimmed.slice(0, trimmed.length - 1).trim();
      if (stmt) statements.push(stmt);
      buffer = '';
    }
  }
}

// Flush remaining (if any)
if (buffer.trim()) statements.push(buffer.trim());

const db = await mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'monster_hunter_geoguesser',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

let ok = 0;
for (let i = 0; i < statements.length; i++) {
  const stmt = statements[i];
  if (!stmt) continue;
  try {
    await db.query(stmt);
    ok++;
  } catch (e) {
    console.error(`Erreur sur la requête #${i + 1}:`, e?.message || e);
    console.error('-----');
    console.error(stmt.slice(0, 5000));
    console.error('-----');
    await db.end();
    process.exit(1);
  }
}

await db.end();
console.log(`OK: ${ok} requêtes exécutées depuis ${sqlFile}`);

