# 拾见 - 失物招领与寻物启事聚合平台

拾见是一个面向校园与周边场景的失物招领聚合平台，提供失物线索浏览、招领/寻物启事发布、地图筛选、收藏、认领申请、消息通知、个人中心和管理员管理等功能。项目覆盖移动端页面、后端 REST API、数据持久化和前后端联调流程，适合作为 HarmonyOS 移动应用与 Node.js 后端结合的完整示例。

## 项目展示

![系统技术架构](docs/images/architecture.png)

<p align="center">
  <img src="docs/images/login.png" width="170" alt="登录界面" />
  <img src="docs/images/home.png" width="170" alt="首页线索列表" />
  <img src="docs/images/map.png" width="170" alt="地图筛选" />
  <img src="docs/images/publish.png" width="170" alt="发布启事" />
  <img src="docs/images/profile.png" width="170" alt="个人中心" />
</p>

## 核心功能

- 用户登录与注册：支持普通用户和管理员角色区分。
- 线索浏览与检索：支持按类型、关键词、状态、地点等条件筛选失物和招领信息。
- 启事发布：用户可填写物品类型、名称、分类、地点、时间、描述、联系方式和核验问题。
- 地图筛选：按教学楼、图书馆、运动区、其他等地点分组展示附近线索。
- 个人中心：包含可信档案、我的发布、我的收藏、消息通知等内容。
- 认领流程：支持联系发布者、提交认领申请、更新归还状态。
- 管理后台：管理员可查看统计信息、用户列表、线索列表，并处理异常数据。

## 技术栈

- 移动端：HarmonyOS ArkTS / ArkUI
- 后端：Node.js + Express
- 接口：REST API，前后端通过 JSON 数据通信
- 数据模型：User、Item、Favorite、ClaimRequest、MessageNotice
- 数据持久化：项目包含 Prisma / MySQL 数据模型，也包含 `server` 目录下的 SQLite 演示后端

## 项目结构

```text
.
├── AppScope/                         # HarmonyOS 应用级配置与资源
├── entry/                            # HarmonyOS ArkTS 移动端主模块
│   └── src/main/ets/
│       ├── common/ApiService.ets     # 前端接口请求封装
│       ├── model/LostFoundItem.ets   # 前端数据模型
│       └── pages/                    # 登录、首页、地图、发布、消息、我的等页面
├── prisma/
│   ├── schema.prisma                 # Prisma 数据模型
│   └── migrations/                   # 数据库迁移文件
├── server/                           # SQLite 版本后端服务
├── index.js                          # Prisma / MySQL 版本后端服务入口
├── package.json                      # 根目录后端依赖与脚本
└── docs/images/                      # README 展示图片
```

## 主要接口

| 接口 | 方法 | 说明 |
| --- | --- | --- |
| `/api/health` | GET | 服务健康检查 |
| `/api/login` | POST | 用户或管理员登录 |
| `/api/register` | POST | 新用户注册 |
| `/api/items` | GET | 查询失物/招领线索 |
| `/api/items` | POST | 发布新的失物或招领启事 |
| `/api/items/:id` | GET | 查看线索详情 |
| `/api/items/:id/favorite` | POST | 收藏或取消收藏 |
| `/api/items/:id/claim` | POST | 提交认领申请 |
| `/api/items/:id/return` | POST | 标记归还 |
| `/api/stations` | GET | 获取地图点位数据 |
| `/api/profile` | GET | 获取个人主页数据 |
| `/api/messages` | GET | 获取消息通知 |
| `/api/admin/stats` | GET | 管理端统计 |
| `/api/admin/users` | GET | 管理端用户列表 |
| `/api/admin/items` | GET | 管理端线索列表 |

## 数据模型

- `User`：保存账号、角色、认证状态、可信分和发布统计。
- `Item`：保存失物或招领启事，是平台核心业务数据。
- `Favorite`：保存用户收藏线索的关系。
- `ClaimRequest`：保存认领申请、核验答案和处理状态。
- `MessageNotice`：保存系统消息与通知状态。

## 运行说明

### 启动 Prisma / MySQL 后端

```powershell
npm install
Copy-Item .env.example .env
npx prisma generate
npx prisma migrate deploy
npm run dev
```

`.env` 中需要配置数据库连接地址：

```env
DATABASE_URL="mysql://user:password@localhost:3306/shijian_lost_found"
JWT_SECRET="your_jwt_secret_here"
```

### 启动 SQLite 演示后端

```powershell
cd server
npm install
npm run dev
```

默认服务地址：

```text
http://127.0.0.1:3000
```

### 运行 HarmonyOS 移动端

1. 使用 DevEco Studio 打开项目。
2. 根据后端所在电脑的局域网 IP，修改 `entry/src/main/ets/common/ApiService.ets` 中的 `API_BASE_URL`。
3. 启动后端服务。
4. 在 HarmonyOS 模拟器或真机中运行 `entry` 模块。

## 项目特点

- 移动端入口清晰，围绕首页、地图、发布、消息、我的组织主要流程。
- 后端接口集中，便于前端统一调用和调试。
- 使用 `ownerId` 区分不同用户发布的数据，支持“我的发布”和“我的收藏”隔离。
- 预留认领申请、消息通知、图片地址、管理员统计等扩展能力。
- 适合继续扩展为带图片上传、真实地图定位、审核流程和权限校验的完整应用。

## 原创声明

本项目为原创失物招领平台项目，仅用于学习、展示与交流。未经许可，请勿直接复制、搬运或用于商业用途。

本仓库未选择开源许可证，除非另有说明，项目代码、文档与相关素材保留所有权利。项目中使用的第三方依赖遵循其原有开源协议。
