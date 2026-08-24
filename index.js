const express = require('express')
const cors = require('cors')
const { PrismaClient } = require('@prisma/client')

const app = express()
const port = 3000
const prisma = new PrismaClient()

app.use(cors())
app.use(express.json({ limit: '10mb' }))

function toTime(value) {
  return value ? new Date(value).getTime() : Date.now()
}

function formatUser(user) {
  return {
    id: user.id,
    name: user.name,
    account: user.account,
    password: user.password,
    role: user.role,
    avatarText: user.avatarText,
    verification: user.verification,
    trustScore: user.trustScore,
    publishingCount: user.publishingCount,
    recoveredCount: user.recoveredCount,
    returnedCount: user.returnedCount,
    createdAt: toTime(user.createdAt)
  }
}

function formatItem(item) {
  const claim = item.claims && item.claims.length > 0 ? item.claims[0] : null

  return {
    id: item.id,
    ownerId: item.ownerId,
    type: item.type,
    status: item.status,
    title: item.title,
    category: item.category,
    source: item.source,
    location: item.location,
    distance: item.distance,
    eventTime: item.eventTime,
    description: item.description,
    contactName: item.contactName,
    contactPhone: item.contactPhone,
    privacyNote: item.privacyNote,
    verificationQuestion: item.verificationQuestion,
    verificationAnswer: item.verificationAnswer,
    score: item.score,
    scoreLabel: item.scoreLabel,
    iconText: item.iconText,
    imageUrl: item.imageUrl,
    color: item.color,
    createdAt: toTime(item.createdAt),
    updatedAt: toTime(item.updatedAt),
    ownerName: item.owner ? item.owner.name : '',
    ownerVerification: item.owner ? item.owner.verification : '',
    favorite: item.favorites && item.favorites.length > 0 ? 1 : 0,
    claimRequestId: claim ? claim.id : 0,
    claimStatus: claim ? claim.status : '',
    claimAnswer: claim ? claim.answer : ''
  }
}

function formatMessage(message) {
  return {
    id: message.id,
    userId: message.userId,
    itemId: message.itemId,
    type: message.type,
    title: message.title,
    content: message.content,
    timeText: message.timeText,
    unread: message.unread,
    createdAt: toTime(message.createdAt)
  }
}

function formatClaim(claim) {
  return {
    id: claim.id,
    itemId: claim.itemId,
    claimantId: claim.claimantId,
    answer: claim.answer,
    note: claim.note,
    status: claim.status,
    createdAt: toTime(claim.createdAt),
    updatedAt: toTime(claim.updatedAt)
  }
}

function asyncHandler(fn) {
  return function (req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}

app.get('/', (req, res) => {
  res.send('后端服务启动成功！')
})

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: '服务运行正常' })
})

app.post('/api/register', asyncHandler(async (req, res) => {
  const { name, account, username, password, role } = req.body
  const finalAccount = account || username
  const finalName = name || finalAccount
  const finalRole = role === 'admin' ? 'admin' : 'user'

  if (!finalAccount || !password) {
    return res.status(400).json({ message: '账号和密码不能为空' })
  }

  const exists = await prisma.user.findUnique({
    where: { account: finalAccount }
  })

  if (exists) {
    return res.status(409).json({ message: '账号已存在' })
  }

  const user = await prisma.user.create({
    data: {
      name: finalName,
      account: finalAccount,
      password,
      role: finalRole,
      avatarText: finalName.substring(0, 1),
      verification: finalRole === 'admin' ? '管理员' : '未认证',
      trustScore: finalRole === 'admin' ? 100 : 80,
      publishingCount: 0,
      recoveredCount: 0,
      returnedCount: 0
    }
  })

  res.json({
    token: `${user.role}-token-${user.account}`,
    user: formatUser(user)
  })
}))

app.post('/api/login', asyncHandler(async (req, res) => {
  const { name, username, account, password, role } = req.body
  const finalAccount = username || account
  const finalRole = role === 'admin' ? 'admin' : 'user'
  const finalName = name || finalAccount

  if (!finalAccount || !password) {
    return res.status(400).json({ message: '账号和密码不能为空' })
  }

  let user = await prisma.user.findUnique({
    where: { account: finalAccount }
  })

  if (user) {
    if (user.password !== password || user.role !== finalRole) {
      return res.status(401).json({ message: '账号或密码错误' })
    }
  } else {
    if (finalRole === 'admin') {
      return res.status(401).json({ message: '管理员账号不存在' })
    }

    user = await prisma.user.create({
      data: {
        name: finalName,
        account: finalAccount,
        password,
        role: 'user',
        avatarText: finalName.substring(0, 1),
        verification: '未认证',
        trustScore: 80,
        publishingCount: 0,
        recoveredCount: 0,
        returnedCount: 0
      }
    })
  }

  res.json({
    token: `${user.role}-token-${user.account}`,
    user: formatUser(user)
  })
}))

app.get('/api/items', asyncHandler(async (req, res) => {
  const userId = Number(req.query.userId || 0)
  const type = String(req.query.type || 'all')
  const keyword = String(req.query.keyword || '')
  const status = String(req.query.status || '全部')
  const owner = String(req.query.owner || '')
  const favorite = String(req.query.favorite || '')

  const where = {}

  if (type && type !== 'all') {
    where.type = type
  }

  if (status && status !== '全部') {
    where.status = status
  }

  if (keyword) {
    where.OR = [
      { title: { contains: keyword } },
      { description: { contains: keyword } },
      { location: { contains: keyword } },
      { category: { contains: keyword } }
    ]
  }

  // 我的发布：只查当前登录用户发布的内容
  if (owner && userId) {
    where.ownerId = userId
  }

  // 我的收藏：只查当前登录用户收藏的内容
  if (favorite === '1' && userId) {
    where.favorites = {
      some: { userId }
    }
  }

  const items = await prisma.item.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    include: {
      owner: true,
      favorites: userId ? { where: { userId } } : true,
      claims: userId ? { where: { claimantId: userId }, orderBy: { createdAt: 'desc' } } : true
    }
  })

  res.json(items.map(formatItem))
}))

app.get('/api/items/:id', asyncHandler(async (req, res) => {
  const id = Number(req.params.id)
  const userId = Number(req.query.userId || 0)

  const item = await prisma.item.findUnique({
    where: { id },
    include: {
      owner: true,
      favorites: userId ? { where: { userId } } : true,
      claims: userId ? { where: { claimantId: userId }, orderBy: { createdAt: 'desc' } } : true
    }
  })

  if (!item) {
    return res.status(404).json({ message: '线索不存在' })
  }

  res.json(formatItem(item))
}))

app.post('/api/items', asyncHandler(async (req, res) => {
  const body = req.body
  const userId = Number(body.userId || body.ownerId || 1)

  const owner = await prisma.user.findUnique({
    where: { id: userId }
  })

  if (!owner) {
    return res.status(404).json({ message: '用户不存在' })
  }

  const item = await prisma.item.create({
    data: {
      ownerId: userId,
      type: body.type || 'found',
      status: body.type === 'lost' ? '寻物中' : '已招领',
      title: body.title || '',
      category: body.category || '其他',
      source: body.source || '其他',
      location: body.location || '',
      distance: body.distance || '',
      eventTime: body.eventTime || '',
      description: body.description || '',
      contactName: body.contactName || owner.name,
      contactPhone: body.contactPhone || '',
      privacyNote: body.privacyNote || '',
      verificationQuestion: body.verificationQuestion || '',
      verificationAnswer: body.verificationAnswer || '',
      score: 90,
      scoreLabel: '新发布',
      iconText: body.category ? body.category.substring(0, 1) : '物',
      imageUrl: body.imageUrl || '',
      color: body.type === 'lost' ? '#16A34A' : '#2F6BFF'
    },
    include: {
      owner: true,
      favorites: true,
      claims: true
    }
  })

  await prisma.user.update({
    where: { id: userId },
    data: { publishingCount: { increment: 1 } }
  })

  res.json(formatItem(item))
}))

app.post('/api/uploads', asyncHandler(async (req, res) => {
  const fileName = req.body.fileName || `upload-${Date.now()}.png`

  res.json({
    fileName,
    imageUrl: ''
  })
}))

app.post('/api/items/:id/status', asyncHandler(async (req, res) => {
  const id = Number(req.params.id)
  const { status } = req.body

  const item = await prisma.item.update({
    where: { id },
    data: { status },
    include: {
      owner: true,
      favorites: true,
      claims: true
    }
  })

  res.json(formatItem(item))
}))

app.post('/api/items/:id/contact', asyncHandler(async (req, res) => {
  const id = Number(req.params.id)

  const item = await prisma.item.findUnique({
    where: { id }
  })

  if (!item) {
    return res.status(404).json({ message: '线索不存在' })
  }

  res.json({
    contactName: item.contactName,
    contactPhone: item.contactPhone,
    message: '联系方式获取成功'
  })
}))

app.post('/api/items/:id/claim', asyncHandler(async (req, res) => {
  const itemId = Number(req.params.id)
  const userId = Number(req.body.userId)
  const answer = req.body.answer || ''
  const note = req.body.note || ''

  const claim = await prisma.claimRequest.create({
    data: {
      itemId,
      claimantId: userId,
      answer,
      note,
      status: '待审核'
    }
  })

  await prisma.item.update({
    where: { id: itemId },
    data: { status: '认领核验中' }
  })

  res.json(formatClaim(claim))
}))

app.post('/api/items/:id/return', asyncHandler(async (req, res) => {
  const id = Number(req.params.id)

  const item = await prisma.item.update({
    where: { id },
    data: { status: '已归还' },
    include: {
      owner: true,
      favorites: true,
      claims: true
    }
  })

  res.json(formatItem(item))
}))

app.post('/api/items/:id/favorite', asyncHandler(async (req, res) => {
  const itemId = Number(req.params.id)
  const userId = Number(req.body.userId)

  const exists = await prisma.favorite.findUnique({
    where: {
      userId_itemId: {
        userId,
        itemId
      }
    }
  })

  if (exists) {
    await prisma.favorite.delete({
      where: { id: exists.id }
    })

    return res.json({
      favorite: 0,
      message: '已取消收藏'
    })
  }

  await prisma.favorite.create({
    data: {
      userId,
      itemId
    }
  })

  res.json({
    favorite: 1,
    message: '收藏成功'
  })
}))

app.get('/api/profile', asyncHandler(async (req, res) => {
  const userId = Number(req.query.userId || 1)

  const user = await prisma.user.findUnique({
    where: { id: userId }
  })

  if (!user) {
    return res.status(404).json({ message: '用户不存在' })
  }

  res.json(formatUser(user))
}))

app.get('/api/messages', asyncHandler(async (req, res) => {
  const userId = Number(req.query.userId || 0)

  const messages = await prisma.messageNotice.findMany({
    where: userId ? { userId } : {},
    orderBy: { createdAt: 'desc' }
  })

  res.json(messages.map(formatMessage))
}))

app.post('/api/messages/:id/read', asyncHandler(async (req, res) => {
  const id = Number(req.params.id)

  const message = await prisma.messageNotice.update({
    where: { id },
    data: { unread: 0 }
  })

  res.json(formatMessage(message))
}))

function getLocationGroup(location = '') {
  const text = String(location || '').trim()

  if (
    text.includes('教学楼') ||
      text.includes('教室') ||
      text.includes('实验楼') ||
      text.includes('实训楼') ||
      text.includes('教学区') ||
      text.includes('A区') ||
      text.includes('B区')
  ) {
    return '教学楼'
  }

  if (
    text.includes('图书馆') ||
      text.includes('阅览室') ||
      text.includes('自习室')
  ) {
    return '图书馆'
  }

  if (
    text.includes('操场') ||
      text.includes('体育馆') ||
      text.includes('运动场') ||
      text.includes('篮球场') ||
      text.includes('足球场') ||
      text.includes('羽毛球场') ||
      text.includes('乒乓球') ||
      text.includes('跑道')
  ) {
    return '运动区'
  }

  return '其他'
}

app.get('/api/stations', asyncHandler(async (req, res) => {
  const source = String(req.query.source || '全部').trim()

  const items = await prisma.item.findMany({
    orderBy: { createdAt: 'desc' }
  })

  const filteredItems = items.filter((item) => {
    const group = getLocationGroup(item.location)

    if (source === '全部') {
      return true
    }

    return group === source
  })

  const mapPositions = {
    '教学楼': [
      { mapX: 32, mapY: 38 },
      { mapX: 46, mapY: 42 },
      { mapX: 58, mapY: 36 }
    ],
    '图书馆': [
      { mapX: 58, mapY: 50 },
      { mapX: 66, mapY: 44 }
    ],
    '运动区': [
      { mapX: 36, mapY: 44 },
      { mapX: 28, mapY: 56 }
    ],
    '其他': [
      { mapX: 34, mapY: 38 },
      { mapX: 48, mapY: 50 },
      { mapX: 66, mapY: 58 }
    ]
  }

  const groupIndexMap = {}

  res.json(filteredItems.map((item, index) => {
    const group = getLocationGroup(item.location)
    const positions = mapPositions[group] || mapPositions['其他']
    const groupIndex = groupIndexMap[group] || 0

    groupIndexMap[group] = groupIndex + 1

    const position = positions[groupIndex % positions.length]

    return {
      id: index + 1,
      name: item.location || '未知地点',
      source: group,
      itemId: item.id,
      itemTitle: item.title,
      timeText: item.eventTime,
      distance: item.distance,
      statusText: item.status,
      mapX: position.mapX,
      mapY: position.mapY,
      color: item.color
    }
  }))
}))

app.get('/api/admin/stats', asyncHandler(async (req, res) => {
  const totalUsers = await prisma.user.count()
  const totalItems = await prisma.item.count()
  const foundItems = await prisma.item.count({ where: { type: 'found' } })
  const lostItems = await prisma.item.count({ where: { type: 'lost' } })
  const returnedItems = await prisma.item.count({ where: { status: '已归还' } })
  const pendingItems = await prisma.item.count({ where: { status: '认领核验中' } })
  const totalMessages = await prisma.messageNotice.count()
  const unreadMessages = await prisma.messageNotice.count({ where: { unread: 1 } })

  res.json({
    totalUsers,
    totalItems,
    foundItems,
    lostItems,
    returnedItems,
    pendingItems,
    totalMessages,
    unreadMessages
  })
}))

app.get('/api/admin/users', asyncHandler(async (req, res) => {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'desc' }
  })

  res.json(users.map(formatUser))
}))

app.get('/api/admin/items', asyncHandler(async (req, res) => {
  const items = await prisma.item.findMany({
    orderBy: { createdAt: 'desc' },
    include: {
      owner: true,
      favorites: true,
      claims: true
    }
  })

  res.json(items.map(formatItem))
}))

app.delete('/api/admin/items/:id', asyncHandler(async (req, res) => {
  const itemId = Number(req.params.id)

  await prisma.$transaction([
    prisma.favorite.deleteMany({ where: { itemId } }),
    prisma.claimRequest.deleteMany({ where: { itemId } }),
    prisma.messageNotice.deleteMany({ where: { itemId } }),
    prisma.item.delete({ where: { id: itemId } })
  ])

  res.json({ message: '删除成功' })
}))

app.delete('/api/items/:id', asyncHandler(async (req, res) => {
  const itemId = Number(req.params.id)

  await prisma.$transaction([
    prisma.favorite.deleteMany({ where: { itemId } }),
    prisma.claimRequest.deleteMany({ where: { itemId } }),
    prisma.messageNotice.deleteMany({ where: { itemId } }),
    prisma.item.delete({ where: { id: itemId } })
  ])

  res.json({ message: '删除成功' })
}))

app.delete('/api/admin/users/:id', asyncHandler(async (req, res) => {
  const userId = Number(req.params.id)

  if (userId === 1) {
    return res.status(400).json({ message: '默认测试用户不建议删除' })
  }

  await prisma.user.delete({
    where: { id: userId }
  })

  res.json({ message: '删除成功' })
}))

app.put('/api/admin/users/:id/role', asyncHandler(async (req, res) => {
  const targetUserId = Number(req.params.id)
  const role = req.body.role === 'admin' ? 'admin' : 'user'

  const user = await prisma.user.update({
    where: { id: targetUserId },
    data: {
      role,
      verification: role === 'admin' ? '管理员' : '已认证'
    }
  })

  res.json(formatUser(user))
}))

app.use((err, req, res, next) => {
  console.error('后端错误：', err)

  res.status(500).json({
    message: err.message || '服务器内部错误'
  })
})

app.listen(port, '0.0.0.0', () => {
  console.log(`服务运行在 http://localhost:${port}`)
})