# Cloudflare 自动部署指南

此项目已配置为自动部署到 Cloudflare Pages（前端）和 Cloudflare Workers（后端）。

## 架构概览

```
vite-plus-project/
├── apps/
│   ├── website/          → 前端应用 (Vite + TypeScript)
│   │   └── dist/         → 部署到 Cloudflare Pages
│   └── api/              → 后端 API (Hono + Workers)
│       └── 部署到 Cloudflare Workers
├── packages/
│   └── utils/            → 共享工具库
└── .github/workflows/
    └── deploy.yml        → 自动部署工作流
```

## 前置要求

### 1. Cloudflare 账户和 API Token

访问 [Cloudflare Dashboard](https://dash.cloudflare.com) 获取：

- **API Token**：用于部署权限
  - 路径：Account Settings → API Tokens → Create Token
  - 权限：Workers Scripts (Edit), Workers D1 (Edit), Pages (Manage)

- **Account ID**：在任何 Workers 或 Pages 项目中可见
  - 复制此值以备后用

### 2. GitHub Secrets 配置

在 GitHub 仓库中添加两个 secrets：

1. `Settings` → `Secrets and variables` → `Actions`
2. 创建两个 secrets：
   - `CLOUDFLARE_API_TOKEN`：粘贴你的 API Token
   - `CLOUDFLARE_ACCOUNT_ID`：粘贴你的 Account ID

### 3. Cloudflare Pages 项目准备

在 Cloudflare Dashboard 中：

1. 进入 `Pages` → `Create a project` → `Upload assets`
2. 项目名称设置为：`vite-plus-project-website`
3. 这样就可以通过 Wrangler CLI 进行部署了

## 本地开发

### 启动开发服务器

```bash
vp dev
```

这会启动前端开发服务器和后端 Worker。

### 前端开发

```bash
vp run website#dev
```

访问 `http://localhost:5173`

### 后端开发

```bash
vp run api#dev
```

访问 `http://localhost:8787/api/health`

## 本地构建测试

### 构建前端

```bash
vp run website#build
# 输出在 apps/website/dist/
```

### 测试部署（前端）

```bash
cd apps/website
vp exec wrangler pages deploy dist --project-name=vite-plus-project-website
```

### 部署后端到 Workers

```bash
cd apps/api
vp run deploy
# 或使用 wrangler
vp exec wrangler deploy
```

## 自动部署工作流

当你将代码推送到 `main` 或 `master` 分支时，GitHub Actions 会自动：

1. **代码检查**
   - 运行格式检查（vp check）
   - 运行 TypeScript 类型检查
   - 运行 linter（oxlint）

2. **测试**
   - 运行单元测试（vp test）

3. **构建**
   - 构建前端应用
   - 准备后端代码

4. **部署**
   - 将 API 部署到 Cloudflare Workers
   - 将前端部署到 Cloudflare Pages

## 部署状态检查

### 查看 GitHub Actions 日志

1. 进入仓库 → `Actions` 标签
2. 点击最新的工作流运行
3. 查看每个步骤的日志

### 验证部署成功

#### Workers 部署

- 访问 Cloudflare Dashboard → Workers
- 查看 `vite-plus-project-api` 是否已更新
- 测试 API：`https://vite-plus-project-api.{your-account}.workers.dev/api/health`

#### Pages 部署

- 访问 Cloudflare Dashboard → Pages
- 查看 `vite-plus-project-website` 的最新部署
- 点击预览 URL 查看实时网站

## 故障排除

### 部署失败？

1. **检查 GitHub Secrets**
   - 确认 `CLOUDFLARE_API_TOKEN` 和 `CLOUDFLARE_ACCOUNT_ID` 已正确设置
   - API Token 是否有过期？需要重新生成

2. **检查 Cloudflare Pages 项目**
   - 项目名称是否为 `vite-plus-project-website`？
   - 项目是否真的存在？如果没有，先在 Dashboard 中手动创建

3. **本地验证**
   ```bash
   vp check
   vp run website#build
   cd apps/api && vp run deploy --dry-run
   ```

### Workers 部署问题？

- Wrangler 版本过旧？运行 `vp run api#dev` 会下载最新版本
- D1 数据库未初始化？运行 `vp run api#db:migrate:local`

## 手动部署

如果需要手动部署（不通过 GitHub Actions）：

### 前端

```bash
cd apps/website
vp build
vp exec wrangler pages deploy dist --project-name=vite-plus-project-website
```

### 后端

```bash
cd apps/api
vp deploy
```

## 环境变量

### Workers（后端）

在 `apps/api/wrangler.toml` 中配置：

```toml
[env.production]
vars = { ENVIRONMENT = "production" }
```

### Pages（前端）

任何需要的环境变量可以通过 Cloudflare Dashboard 的 Pages 项目设置中添加。

## 更多信息

- [Vite+ 文档](https://vite-plus.dev)
- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [Cloudflare Pages 文档](https://developers.cloudflare.com/pages/)
- [Hono 框架文档](https://hono.dev)
