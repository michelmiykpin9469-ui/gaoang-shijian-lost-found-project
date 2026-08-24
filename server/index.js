const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const express = require('express');
const cors = require('cors');
const { DatabaseSync } = require('node:sqlite');

const PORT = Number(process.env.PORT || 3000);
const DATA_DIR = path.join(__dirname, 'data');
const DB_PATH = path.join(DATA_DIR, 'lost_found.sqlite');
const UPLOAD_DIR = path.join(__dirname, 'uploads');

fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA foreign_keys = ON');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  account TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'user',
  avatarText TEXT NOT NULL,
  verification TEXT NOT NULL,
  trustScore INTEGER NOT NULL DEFAULT 80,
  publishingCount INTEGER NOT NULL DEFAULT 0,
  recoveredCount INTEGER NOT NULL DEFAULT 0,
  returnedCount INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  userId INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  FOREIGN KEY(userId) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ownerId INTEGER NOT NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  source TEXT NOT NULL,
  location TEXT NOT NULL,
  distance TEXT NOT NULL,
  eventTime TEXT NOT NULL,
  description TEXT NOT NULL,
  contactName TEXT NOT NULL,
  contactPhone TEXT NOT NULL,
  privacyNote TEXT NOT NULL,
  verificationQuestion TEXT NOT NULL,
  verificationAnswer TEXT NOT NULL,
  score INTEGER NOT NULL,
  scoreLabel TEXT NOT NULL,
  iconText TEXT NOT NULL,
  imageUrl TEXT NOT NULL DEFAULT '',
  color TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY(ownerId) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS claim_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  itemId INTEGER NOT NULL,
  claimantId INTEGER NOT NULL,
  answer TEXT NOT NULL,
  note TEXT NOT NULL,
  status TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY(itemId) REFERENCES items(id),
  FOREIGN KEY(claimantId) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS favorites (
  userId INTEGER NOT NULL,
  itemId INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  PRIMARY KEY(userId, itemId),
  FOREIGN KEY(userId) REFERENCES users(id),
  FOREIGN KEY(itemId) REFERENCES items(id)
);

CREATE TABLE IF NOT EXISTS stations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  source TEXT NOT NULL,
  itemId INTEGER,
  itemTitle TEXT NOT NULL,
  timeText TEXT NOT NULL,
  distance TEXT NOT NULL,
  statusText TEXT NOT NULL,
  mapX INTEGER NOT NULL,
  mapY INTEGER NOT NULL,
  color TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL,
  itemId INTEGER,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  timeText TEXT NOT NULL,
  unread INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL,
  FOREIGN KEY(userId) REFERENCES users(id)
);
`);

// 迁移：为已有表添加 password 和 role 字段
const userColumns = db.prepare('PRAGMA table_info(users)').all().map((column) => column.name);
if (!userColumns.includes('password')) {
  db.exec("ALTER TABLE users ADD COLUMN password TEXT NOT NULL DEFAULT ''");
}
if (!userColumns.includes('role')) {
  db.exec("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user'");
}

const itemColumns = db.prepare('PRAGMA table_info(items)').all().map((column) => column.name);
if (!itemColumns.includes('imageUrl')) {
  db.exec("ALTER TABLE items ADD COLUMN imageUrl TEXT NOT NULL DEFAULT ''");
}

function now() {
  return Date.now();
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function tokenFor(userId) {
  return `demo-${userId}-${Date.now()}`;
}

function getUserId(req) {
  const raw = req.header('x-user-id') || req.query.userId || (req.body && req.body.userId) || '1';
  const userId = Number(raw);
  return Number.isFinite(userId) && userId > 0 ? userId : 1;
}

function requireString(body, key) {
  const value = String((body || {})[key] || '').trim();
  if (!value) {
    throw new Error(`缺少字段：${key}`);
  }
  return value;
}

function normalizeType(type) {
  if (!type || type === 'all' || type === '全部') return '';
  if (type === '招领' || type === 'found') return 'found';
  if (type === '寻物' || type === 'lost') return 'lost';
  return String(type);
}

function itemStatusFor(type) {
  return type === 'lost' ? '寻物中' : '已招领';
}

function iconFor(category) {
  const map = {
    证件: '证',
    数码: '耳',
    日用品: '杯',
    钥匙: '钥',
    书籍: '书',
    其他: '物'
  };
  return map[category] || '物';
}

function createMessage(userId, itemId, type, title, content, unread = 1) {
  db.prepare(`
    INSERT INTO messages (userId, itemId, type, title, content, timeText, unread, createdAt)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(userId, itemId || null, type, title, content, '刚刚', unread, now());
}

function refreshStats(userId) {
  const publishingCount = db.prepare(`
    SELECT COUNT(*) AS total FROM items
    WHERE ownerId = ? AND status IN ('已招领', '寻物中', '认领核验中')
  `).get(userId).total;
  const recoveredCount = db.prepare(`
    SELECT COUNT(*) AS total FROM items
    WHERE ownerId = ? AND status IN ('已找回', '已归还')
  `).get(userId).total;
  const returnedCount = db.prepare(`
    SELECT COUNT(*) AS total FROM items
    WHERE ownerId = ? AND status = '已归还'
  `).get(userId).total;
  db.prepare(`
    UPDATE users
    SET publishingCount = ?, recoveredCount = ?, returnedCount = ?,
        trustScore = MIN(100, 80 + ? * 2 + ?)
    WHERE id = ?
  `).run(publishingCount, recoveredCount, returnedCount, returnedCount, recoveredCount, userId);
}

function itemSelectSql(userId, whereSql = '') {
  return `
    SELECT i.*,
      u.name AS ownerName,
      u.verification AS ownerVerification,
      CASE WHEN f.itemId IS NULL THEN 0 ELSE 1 END AS favorite,
      COALESCE(cr.id, 0) AS claimRequestId,
      COALESCE(cr.status, '') AS claimStatus,
      COALESCE(cr.answer, '') AS claimAnswer
    FROM items i
    JOIN users u ON u.id = i.ownerId
    LEFT JOIN favorites f ON f.itemId = i.id AND f.userId = ${Number(userId)}
    LEFT JOIN claim_requests cr ON cr.itemId = i.id AND cr.claimantId = ${Number(userId)}
    ${whereSql}
  `;
}

function seed() {
  const userCount = db.prepare('SELECT COUNT(*) AS total FROM users').get().total;
  if (userCount === 0) {
    const insertUser = db.prepare(`
      INSERT INTO users (name, account, password, role, avatarText, verification, trustScore, publishingCount, recoveredCount, returnedCount, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    insertUser.run('林同学', '20260001', hashPassword('123456'), 'user', '林', '实名认证 · 校园邮箱已验证', 86, 0, 0, 0, now());
    insertUser.run('图书馆服务台', 'library', hashPassword('123456'), 'user', '图', '校园服务站 · 已认证', 92, 0, 0, 0, now());
    insertUser.run('管理员', 'admin', hashPassword('admin123'), 'admin', '管', '系统管理员 · 最高权限', 100, 0, 0, 0, now());
  } else {
    // 为已有用户更新密码和角色
    const adminExists = db.prepare("SELECT COUNT(*) AS total FROM users WHERE role = 'admin'").get().total;
    if (adminExists === 0) {
      db.prepare(`
        INSERT INTO users (name, account, password, role, avatarText, verification, trustScore, publishingCount, recoveredCount, returnedCount, createdAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run('管理员', 'admin', hashPassword('admin123'), 'admin', '管', '系统管理员 · 最高权限', 100, 0, 0, 0, now());
    }
    // 确保已有用户有密码
    const usersWithoutPassword = db.prepare("SELECT id FROM users WHERE password = ''").all();
    for (const u of usersWithoutPassword) {
      db.prepare("UPDATE users SET password = ? WHERE id = ?").run(hashPassword('123456'), u.id);
    }
  }

  const itemCount = db.prepare('SELECT COUNT(*) AS total FROM items').get().total;
  if (itemCount === 0) {
    const insertItem = db.prepare(`
      INSERT INTO items
      (ownerId, type, status, title, category, source, location, distance, eventTime, description, contactName, contactPhone, privacyNote, verificationQuestion, verificationAnswer, score, scoreLabel, iconText, imageUrl, color, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const base = now();
    [
      [2, 'found', '已招领', '蓝色证件卡包', '证件', '校园', '图书馆二楼服务台', '320m', '今天 17:40', '内含校园卡与两张门禁卡。为保护隐私，认领前需回答卡包颜色、挂件形状及证件姓名首字。', '图书馆服务台', '010-20260609', '隐藏完整证件号，仅通过特征问答核验', '请说明卡包颜色、挂件形状和证件姓名首字。', '蓝色 星形 林', 92, '可信', '证', '', '#3B82F6', base, base],
      [1, 'lost', '寻物中', '寻找黑色耳机盒', '数码', '地铁', '地铁 4 号线北门站', '1.2km', '42分钟前', '黑色无线耳机盒，外壳有蓝色贴纸，内有课程录音资料。', '林同学', '13800000002', '联系前请说明丢失时间与耳机盒特征', '请描述耳机盒外壳贴纸颜色。', '蓝色', 71, '匹配', '耳', '', '#F59E0B', base - 60000, base - 60000],
      [2, 'found', '可认领', '白色保温杯', '日用品', '校园', '教学楼 A 座', '560m', '今天 12:20', '白色保温杯，杯盖有浅蓝色挂绳，放在教学楼 A 座前台。', 'A座前台', '010-20261220', '认领需描述杯身贴纸和容量', '请描述杯身贴纸和大致容量。', '蓝色贴纸 500ml', 85, '可信', '杯', '', '#2563EB', base - 120000, base - 120000]
    ].forEach((item) => insertItem.run(...item));
  }

  const stationCount = db.prepare('SELECT COUNT(*) AS total FROM stations').get().total;
  if (stationCount === 0) {
    const insertStation = db.prepare(`
      INSERT INTO stations (name, source, itemId, itemTitle, timeText, distance, statusText, mapX, mapY, color)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    [
      ['图书馆二楼服务台', '校园', 1, '蓝色证件卡包', '18 分钟前', '320m', '招', 40, 32, '#3B82F6'],
      ['4 号线北门站客服处', '地铁', 2, '黑色耳机盒', '42 分钟前', '1.2km', '寻', 74, 42, '#F59E0B'],
      ['校园服务台', '物业', 3, '白色保温杯', '今天 12:20', '560m', '招', 52, 68, '#22C55E']
    ].forEach((station) => insertStation.run(...station));
  }

  const messageCount = db.prepare('SELECT COUNT(*) AS total FROM messages').get().total;
  if (messageCount === 0) {
    createMessage(1, 1, 'AI', '疑似匹配：寻物启事 #A208', '蓝色证件卡包与 1 条寻物启事在物品、地点、时间上高度重合。', 1);
    createMessage(1, null, '系统', '附近站点同步完成', '已同步 3 个招领站点和 18 条附近启事。', 0);
    createMessage(2, 1, '认领', '认领问题库已启用', '蓝色证件卡包已开启特征问答核验，避免冒领。', 0);
  }

  refreshStats(1);
  refreshStats(2);
}

seed();

const app = express();
app.use(cors());
app.use(express.json({ limit: '8mb' }));
app.use('/uploads', express.static(UPLOAD_DIR));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, app: '拾见', database: DB_PATH });
});

app.post('/api/uploads', (req, res) => {
  try {
    const body = req.body || {};
    const rawData = String(body.base64 || '').trim();
    if (!rawData) {
      res.status(400).json({ message: '图片数据不能为空' });
      return;
    }
    const mimeType = String(body.mimeType || 'image/jpeg').trim();
    const ext = mimeType.includes('png') ? 'png' : mimeType.includes('webp') ? 'webp' : 'jpg';
    const fileName = `item-${Date.now()}-${Math.floor(Math.random() * 10000)}.${ext}`;
    const filePath = path.join(UPLOAD_DIR, fileName);
    fs.writeFileSync(filePath, Buffer.from(rawData, 'base64'));
    const host = req.get('host') || `localhost:${PORT}`;
    res.status(201).json({
      fileName,
      imageUrl: `${req.protocol}://${host}/uploads/${fileName}`
    });
  } catch (error) {
    res.status(400).json({ message: '图片上传失败' });
  }
});

// 登录接口 - 支持管理员和普通用户
app.post('/api/auth/login', (req, res) => {
  const body = req.body || {};
  const name = String(body.name || '').trim();
  const account = String(body.account || body.phone || '').trim();
  const password = String(body.password || '').trim();
  const role = String(body.role || 'user').trim();

  if (!account) {
    res.status(400).json({ message: '请输入账号' });
    return;
  }
  if (!password) {
    res.status(400).json({ message: '请输入密码' });
    return;
  }

  let user = db.prepare('SELECT * FROM users WHERE account = ?').get(account);

  if (user) {
    // 已有用户 - 验证密码
    if (user.password !== hashPassword(password)) {
      res.status(401).json({ message: '密码错误' });
      return;
    }
    // 验证角色
    if (role === 'admin' && user.role !== 'admin') {
      res.status(403).json({ message: '该账号不是管理员' });
      return;
    }
  } else {
    // 新用户注册（仅普通用户可注册）
    if (role === 'admin') {
      res.status(403).json({ message: '管理员账号不存在，请联系系统创建' });
      return;
    }
    if (!name) {
      res.status(400).json({ message: '请输入昵称' });
      return;
    }
    const avatarText = name.slice(0, 1) || '拾';
    const result = db.prepare(`
      INSERT INTO users (name, account, password, role, avatarText, verification, trustScore, publishingCount, recoveredCount, returnedCount, createdAt)
      VALUES (?, ?, ?, 'user', ?, ?, 80, 0, 0, 0, ?)
    `).run(name, account, hashPassword(password), avatarText, '校园账号已验证', now());
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(result.lastInsertRowid);
  }

  const token = tokenFor(user.id);
  db.prepare('INSERT INTO sessions (token, userId, createdAt) VALUES (?, ?, ?)').run(token, user.id, now());
  res.json({ token, user });
});

app.get('/api/items', (req, res) => {
  const userId = getUserId(req);
  const type = normalizeType(String(req.query.type || ''));
  const keyword = String(req.query.keyword || '').trim();
  const source = String(req.query.source || '').trim();
  const status = String(req.query.status || '').trim();
  const owner = String(req.query.owner || '').trim();
  const favoriteOnly = String(req.query.favorite || '') === '1';
  const where = [];
  const args = {};

  if (type) {
    where.push('i.type = $type');
    args.$type = type;
  }
  if (keyword) {
    where.push('(i.title LIKE $keyword OR i.category LIKE $keyword OR i.location LIKE $keyword OR i.description LIKE $keyword)');
    args.$keyword = `%${keyword}%`;
  }
  if (source && source !== '全部') {
    where.push('i.source = $source');
    args.$source = source;
  }
  if (status && status !== '全部') {
    where.push('i.status = $status');
    args.$status = status;
  }
  if (owner === 'me') {
    where.push('i.ownerId = $ownerId');
    args.$ownerId = userId;
  }
  if (favoriteOnly) {
    where.push('f.itemId IS NOT NULL');
  }

  const sql = `${itemSelectSql(userId, where.length ? `WHERE ${where.join(' AND ')}` : '')} ORDER BY i.createdAt DESC`;
  res.json(db.prepare(sql).all(args));
});

app.get('/api/items/:id', (req, res) => {
  const userId = getUserId(req);
  const item = db.prepare(`${itemSelectSql(userId, 'WHERE i.id = ?')}`).get(Number(req.params.id));
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  res.json(item);
});

app.post('/api/items', (req, res) => {
  try {
    const body = req.body || {};
    const userId = getUserId(req);
    const type = normalizeType(requireString(body, 'type')) || 'found';
    const category = requireString(body, 'category');
    const status = itemStatusFor(type);
    const result = db.prepare(`
      INSERT INTO items
      (ownerId, type, status, title, category, source, location, distance, eventTime, description, contactName, contactPhone, privacyNote, verificationQuestion, verificationAnswer, score, scoreLabel, iconText, imageUrl, color, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      userId,
      type,
      status,
      requireString(body, 'title'),
      category,
      String(body.source || '校园').trim(),
      requireString(body, 'location'),
      String(body.distance || '新发布').trim(),
      requireString(body, 'eventTime'),
      requireString(body, 'description'),
      requireString(body, 'contactName'),
      requireString(body, 'contactPhone'),
      String(body.privacyNote || '隐藏完整证件号，仅通过特征问答核验').trim(),
      String(body.verificationQuestion || '请描述物品的关键特征。').trim(),
      String(body.verificationAnswer || '特征正确').trim(),
      Number(body.score || 88),
      type === 'lost' ? '匹配' : '可信',
      iconFor(category),
      String(body.imageUrl || '').trim(),
      type === 'lost' ? '#F59E0B' : '#2563EB',
      now(),
      now()
    );
    refreshStats(userId);
    createMessage(userId, result.lastInsertRowid, '系统', '发布成功', '启事已进入聚合线索流，并开启智能匹配。', 1);
    const item = db.prepare(`${itemSelectSql(userId, 'WHERE i.id = ?')}`).get(result.lastInsertRowid);
    res.status(201).json(item);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

app.post('/api/items/:id/status', (req, res) => {
  const userId = getUserId(req);
  const status = String((req.body || {}).status || '').trim();
  if (!status) {
    res.status(400).json({ message: '状态不能为空' });
    return;
  }
  const item = db.prepare('SELECT * FROM items WHERE id = ?').get(Number(req.params.id));
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  db.prepare('UPDATE items SET status = ?, updatedAt = ? WHERE id = ?').run(status, now(), item.id);
  refreshStats(item.ownerId);
  refreshStats(userId);
  createMessage(item.ownerId, item.id, '状态', `${item.title} 状态已更新`, `当前状态：${status}`, 1);
  const updated = db.prepare(`${itemSelectSql(userId, 'WHERE i.id = ?')}`).get(item.id);
  res.json(updated);
});

app.post('/api/items/:id/contact', (req, res) => {
  const userId = getUserId(req);
  const item = db.prepare(`${itemSelectSql(userId, 'WHERE i.id = ?')}`).get(Number(req.params.id));
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  createMessage(item.ownerId, item.id, '联系', `${item.title} 有新的联系请求`, `用户想联系你处理该启事，联系方式已展示。`, 1);
  createMessage(userId, item.id, '联系', `已获取 ${item.title} 联系方式`, `联系人：${item.contactName}，联系方式：${item.contactPhone}`, 0);
  res.json({ contactName: item.contactName, contactPhone: item.contactPhone, message: '联系方式已记录到消息中心' });
});

app.post('/api/items/:id/claim', (req, res) => {
  try {
    const userId = getUserId(req);
    const itemId = Number(req.params.id);
    const answer = requireString(req.body, 'answer');
    const note = String((req.body || {}).note || '').trim();
    const item = db.prepare('SELECT * FROM items WHERE id = ?').get(itemId);
    if (!item) {
      res.status(404).json({ message: '未找到该启事' });
      return;
    }
    const existing = db.prepare('SELECT * FROM claim_requests WHERE itemId = ? AND claimantId = ?').get(itemId, userId);
    if (existing) {
      db.prepare('UPDATE claim_requests SET answer = ?, note = ?, status = ?, updatedAt = ? WHERE id = ?')
        .run(answer, note, '待核验', now(), existing.id);
    } else {
      db.prepare(`
        INSERT INTO claim_requests (itemId, claimantId, answer, note, status, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(itemId, userId, answer, note, '待核验', now(), now());
    }
    db.prepare('UPDATE items SET status = ?, updatedAt = ? WHERE id = ?').run('认领核验中', now(), itemId);
    createMessage(item.ownerId, itemId, '认领', `${item.title} 收到认领申请`, `认领答案：${answer}`, 1);
    createMessage(userId, itemId, '认领', '认领申请已提交', '发布者核验后会更新归还状态。', 1);
    const request = db.prepare('SELECT * FROM claim_requests WHERE itemId = ? AND claimantId = ?').get(itemId, userId);
    res.status(201).json(request);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

app.post('/api/items/:id/return', (req, res) => {
  const userId = getUserId(req);
  const item = db.prepare('SELECT * FROM items WHERE id = ?').get(Number(req.params.id));
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  const nextStatus = item.type === 'lost' ? '已找回' : '已归还';
  db.prepare('UPDATE items SET status = ?, updatedAt = ? WHERE id = ?').run(nextStatus, now(), item.id);
  db.prepare('UPDATE claim_requests SET status = ?, updatedAt = ? WHERE itemId = ?').run('已完成', now(), item.id);
  refreshStats(item.ownerId);
  refreshStats(userId);
  createMessage(item.ownerId, item.id, '闭环', `${item.title} 已完成`, `状态已更新为：${nextStatus}`, 1);
  const updated = db.prepare(`${itemSelectSql(userId, 'WHERE i.id = ?')}`).get(item.id);
  res.json(updated);
});

// 普通用户删除自己发布的启事
app.delete('/api/items/:id', (req, res) => {
  const userId = getUserId(req);
  const itemId = Number(req.params.id);
  const item = db.prepare('SELECT * FROM items WHERE id = ?').get(itemId);
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  if (item.ownerId !== userId) {
    res.status(403).json({ message: '只能删除自己发布的启事' });
    return;
  }
  db.prepare('DELETE FROM favorites WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM claim_requests WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM messages WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM items WHERE id = ?').run(itemId);
  refreshStats(userId);
  res.json({ message: '启事已删除' });
});

app.post('/api/items/:id/favorite', (req, res) => {
  const userId = getUserId(req);
  const itemId = Number(req.params.id);
  const existed = db.prepare('SELECT 1 FROM favorites WHERE userId = ? AND itemId = ?').get(userId, itemId);
  if (existed) {
    db.prepare('DELETE FROM favorites WHERE userId = ? AND itemId = ?').run(userId, itemId);
    res.json({ favorite: 0, message: '已取消收藏' });
  } else {
    db.prepare('INSERT INTO favorites (userId, itemId, createdAt) VALUES (?, ?, ?)').run(userId, itemId, now());
    res.json({ favorite: 1, message: '已收藏' });
  }
});

// 管理员接口：删除启事
app.delete('/api/admin/items/:id', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const itemId = Number(req.params.id);
  const item = db.prepare('SELECT * FROM items WHERE id = ?').get(itemId);
  if (!item) {
    res.status(404).json({ message: '未找到该启事' });
    return;
  }
  db.prepare('DELETE FROM favorites WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM claim_requests WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM messages WHERE itemId = ?').run(itemId);
  db.prepare('DELETE FROM items WHERE id = ?').run(itemId);
  refreshStats(item.ownerId);
  res.json({ message: '启事已删除' });
});

// 管理员接口：获取所有用户
app.get('/api/admin/users', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const users = db.prepare('SELECT id, name, account, role, avatarText, verification, trustScore, publishingCount, recoveredCount, returnedCount, createdAt FROM users ORDER BY id').all();
  res.json(users);
});

// 管理员接口：获取所有启事（含统计）
app.get('/api/admin/items', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const items = db.prepare(`
    SELECT i.*, u.name AS ownerName, u.verification AS ownerVerification
    FROM items i
    JOIN users u ON u.id = i.ownerId
    ORDER BY i.createdAt DESC
  `).all();
  res.json(items);
});

// 管理员接口：删除用户
app.delete('/api/admin/users/:id', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const targetId = Number(req.params.id);
  const targetUser = db.prepare('SELECT * FROM users WHERE id = ?').get(targetId);
  if (!targetUser) {
    res.status(404).json({ message: '未找到该用户' });
    return;
  }
  if (targetUser.role === 'admin') {
    res.status(403).json({ message: '不能删除管理员账号' });
    return;
  }
  // 删除该用户的所有关联数据
  const userItems = db.prepare('SELECT id FROM items WHERE ownerId = ?').all(targetId);
  for (const item of userItems) {
    db.prepare('DELETE FROM favorites WHERE itemId = ?').run(item.id);
    db.prepare('DELETE FROM claim_requests WHERE itemId = ?').run(item.id);
    db.prepare('DELETE FROM messages WHERE itemId = ?').run(item.id);
  }
  db.prepare('DELETE FROM items WHERE ownerId = ?').run(targetId);
  db.prepare('DELETE FROM favorites WHERE userId = ?').run(targetId);
  db.prepare('DELETE FROM claim_requests WHERE claimantId = ?').run(targetId);
  db.prepare('DELETE FROM messages WHERE userId = ?').run(targetId);
  db.prepare('DELETE FROM sessions WHERE userId = ?').run(targetId);
  db.prepare('DELETE FROM users WHERE id = ?').run(targetId);
  res.json({ message: '用户已删除' });
});

// 管理员接口：修改用户角色
app.put('/api/admin/users/:id/role', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const targetId = Number(req.params.id);
  const newRole = String((req.body || {}).role || '').trim();
  if (newRole !== 'user' && newRole !== 'admin') {
    res.status(400).json({ message: '角色只能是 user 或 admin' });
    return;
  }
  const targetUser = db.prepare('SELECT * FROM users WHERE id = ?').get(targetId);
  if (!targetUser) {
    res.status(404).json({ message: '未找到该用户' });
    return;
  }
  if (targetId === userId) {
    res.status(403).json({ message: '不能修改自己的角色' });
    return;
  }
  db.prepare('UPDATE users SET role = ? WHERE id = ?').run(newRole, targetId);
  const updated = db.prepare('SELECT id, name, account, role, avatarText, verification, trustScore, publishingCount, recoveredCount, returnedCount, createdAt FROM users WHERE id = ?').get(targetId);
  res.json(updated);
});

// 管理员接口：获取统计数据
app.get('/api/admin/stats', (req, res) => {
  const userId = getUserId(req);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') {
    res.status(403).json({ message: '需要管理员权限' });
    return;
  }
  const totalUsers = db.prepare('SELECT COUNT(*) AS total FROM users').get().total;
  const totalItems = db.prepare('SELECT COUNT(*) AS total FROM items').get().total;
  const foundItems = db.prepare("SELECT COUNT(*) AS total FROM items WHERE type = 'found'").get().total;
  const lostItems = db.prepare("SELECT COUNT(*) AS total FROM items WHERE type = 'lost'").get().total;
  const returnedItems = db.prepare("SELECT COUNT(*) AS total FROM items WHERE status IN ('已归还', '已找回')").get().total;
  const pendingItems = db.prepare("SELECT COUNT(*) AS total FROM items WHERE status IN ('已招领', '寻物中', '认领核验中')").get().total;
  const totalMessages = db.prepare('SELECT COUNT(*) AS total FROM messages').get().total;
  const unreadMessages = db.prepare('SELECT COUNT(*) AS total FROM messages WHERE unread = 1').get().total;
  res.json({
    totalUsers,
    totalItems,
    foundItems,
    lostItems,
    returnedItems,
    pendingItems,
    totalMessages,
    unreadMessages
  });
});

app.get('/api/stations', (req, res) => {
  const source = String(req.query.source || '').trim();
  if (source && source !== '全部') {
    res.json(db.prepare('SELECT * FROM stations WHERE source = ? ORDER BY id').all(source));
    return;
  }
  res.json(db.prepare('SELECT * FROM stations ORDER BY id').all());
});

app.get('/api/profile', (req, res) => {
  const userId = getUserId(req);
  refreshStats(userId);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  res.json(user);
});

app.get('/api/messages', (req, res) => {
  const userId = getUserId(req);
  res.json(db.prepare('SELECT * FROM messages WHERE userId = ? ORDER BY createdAt DESC').all(userId));
});

app.post('/api/messages/:id/read', (req, res) => {
  const userId = getUserId(req);
  db.prepare('UPDATE messages SET unread = 0 WHERE id = ? AND userId = ?').run(Number(req.params.id), userId);
  const message = db.prepare('SELECT * FROM messages WHERE id = ? AND userId = ?').get(Number(req.params.id), userId);
  res.json(message || { message: '已处理' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`拾见后端已启动：http://localhost:${PORT}`);
  console.log(`SQLite 数据库：${DB_PATH}`);
  console.log(`管理员账号：admin / admin123`);
  console.log(`普通用户账号：20260001 / 123456`);
});
