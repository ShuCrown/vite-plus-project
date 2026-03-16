#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  Vite+ 全栈项目初始化脚本                                      ║
║  React + Cloudflare D1 + pnpm Monorepo                        ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if in correct directory
if [ ! -f "package.json" ] || [ ! -f "pnpm-workspace.yaml" ]; then
  echo -e "${RED}❌ 错误：请在项目根目录运行此脚本${NC}"
  echo "当前目录：$(pwd)"
  exit 1
fi

echo -e "${GREEN}✓ 项目目录验证通过${NC}"
echo ""

# Step 1: Create api package structure
echo -e "${BLUE}📁 第 1 步：创建 API 包结构${NC}"
mkdir -p apps/api/src/routes
mkdir -p apps/api/migrations
echo -e "${GREEN}✓ 创建目录：apps/api${NC}"
echo ""

# Step 2: Create apps/api/package.json
echo -e "${BLUE}📝 第 2 步：生成 apps/api/package.json${NC}"
cat > apps/api/package.json << 'EOF'
{
  "name": "@vite-plus-project/api",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "db:migrate:local": "wrangler d1 migrations apply my-app-db --local",
    "db:migrate:prod": "wrangler d1 migrations apply my-app-db"
  },
  "dependencies": {
    "hono": "^4.7.0"
  },
  "devDependencies": {
    "wrangler": "^3.114.0",
    "@cloudflare/workers-types": "^4.20250310.0",
    "typescript": "^5.3.3"
  }
}
EOF
echo -e "${GREEN}✓ 生成：apps/api/package.json${NC}"
echo ""

# Step 3: Create wrangler.toml
echo -e "${BLUE}⚙️  第 3 步：生成 wrangler.toml${NC}"
cat > apps/api/wrangler.toml << 'EOF'
name = "vite-plus-project-api"
main = "src/index.ts"
compatibility_date = "2025-01-01"
type = "service"

[[d1_databases]]
binding = "DB"
database_name = "my-app-db"
database_id = "REPLACE_WITH_YOUR_DB_ID_AFTER_CREATION"

[env.development]
vars = { ENVIRONMENT = "development" }

[dev]
port = 8787
EOF
echo -e "${GREEN}✓ 生成：apps/api/wrangler.toml${NC}"
echo -e "${YELLOW}⚠️  重要：需要用真实的 database_id 替换 REPLACE_WITH_YOUR_DB_ID_AFTER_CREATION${NC}"
echo ""

# Step 4: Create Hono entry point
echo -e "${BLUE}🚀 第 4 步：创建 Hono 应用入口${NC}"
cat > apps/api/src/index.ts << 'EOF'
import { Hono } from 'hono'
import { cors } from 'hono/cors'

export interface Env {
  DB: D1Database
  ENVIRONMENT?: string
}

const app = new Hono<{ Bindings: Env }>()

app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}))

app.get('/api/health', (c) => {
  return c.json({
    ok: true,
    timestamp: new Date().toISOString(),
    environment: c.env.ENVIRONMENT || 'unknown'
  })
})

app.get('/api/users', async (c) => {
  try {
    const { results } = await c.env.DB.prepare('SELECT * FROM users ORDER BY created_at DESC').all()
    return c.json({
      success: true,
      data: results,
      count: results?.length || 0
    })
  } catch (error) {
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Database error'
    }, 500)
  }
})

app.post('/api/users', async (c) => {
  try {
    const body = await c.req.json()
    const { name, email } = body

    if (!name || !email) {
      return c.json({
        success: false,
        error: 'name and email are required'
      }, 400)
    }

    const result = await c.env.DB.prepare(
      'INSERT INTO users (name, email) VALUES (?, ?) RETURNING *'
    ).bind(name, email).first()

    return c.json({
      success: true,
      data: result
    }, 201)
  } catch (error) {
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Database error'
    }, 500)
  }
})

app.get('/api/users/:id', async (c) => {
  try {
    const id = c.req.param('id')
    const result = await c.env.DB.prepare(
      'SELECT * FROM users WHERE id = ?'
    ).bind(id).first()

    if (!result) {
      return c.json({
        success: false,
        error: 'User not found'
      }, 404)
    }

    return c.json({
      success: true,
      data: result
    })
  } catch (error) {
    return c.json({
      success: false,
      error: error instanceof Error ? error.message : 'Database error'
    }, 500)
  }
})

export default app
EOF
echo -e "${GREEN}✓ 创建：apps/api/src/index.ts${NC}"
echo ""

# Step 5: Create D1 migration file
echo -e "${BLUE}🗄️  第 5 步：创建数据库迁移脚本${NC}"
cat > apps/api/migrations/0001_init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

INSERT OR IGNORE INTO users (id, name, email) VALUES
  (1, 'Alice Johnson', 'alice@example.com'),
  (2, 'Bob Smith', 'bob@example.com'),
  (3, 'Charlie Brown', 'charlie@example.com');
EOF
echo -e "${GREEN}✓ 创建：apps/api/migrations/0001_init.sql${NC}"
echo ""

# Step 6: Create .dev.vars
echo -e "${BLUE}🔐 第 6 步：创建本地环境变量文件${NC}"
cat > apps/api/.dev.vars << 'EOF'
ENVIRONMENT=development
EOF
echo -e "${GREEN}✓ 创建：apps/api/.dev.vars${NC}"
echo ""

# Step 7: Update vite.config.ts
echo -e "${BLUE}⚡ 第 7 步：更新前端 vite.config.ts（添加 API 代理）${NC}"
if [ -f "apps/web/vite.config.ts" ]; then
  if ! grep -q "'/api'" apps/web/vite.config.ts; then
    cp apps/web/vite.config.ts apps/web/vite.config.ts.backup
    cat > apps/web/vite.config.ts << 'VITE_EOF'
import { defineConfig } from 'vite-plus'

export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8787',
        changeOrigin: true,
        secure: false,
      }
    }
  }
})
VITE_EOF
    echo -e "${GREEN}✓ 更新：apps/web/vite.config.ts${NC}"
  else
    echo -e "${GREEN}✓ API 代理已存在${NC}"
  fi
fi
echo ""

# Step 8: Update .gitignore
echo -e "${BLUE}🔒 第 8 步：更新 .gitignore${NC}"
for pattern in ".dev.vars" "apps/api/.dev.vars"; do
  if [ -f ".gitignore" ]; then
    if ! grep -q "^$pattern$" .gitignore; then
      echo "$pattern" >> .gitignore
    fi
  fi
done
echo -e "${GREEN}✓ 更新 .gitignore${NC}"
echo ""

# Final summary
echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  ✅ 初始化完成！                                               ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}📋 已创建的文件：${NC}"
echo "  ✓ apps/api/package.json"
echo "  ✓ apps/api/wrangler.toml"
echo "  ✓ apps/api/src/index.ts"
echo "  ✓ apps/api/migrations/0001_init.sql"
echo "  ✓ apps/api/.dev.vars"
echo "  ✓ apps/web/vite.config.ts (已更新)"
echo ""

echo -e "${BLUE}🚀 下一步操作：${NC}"
echo ""
echo -e "${YELLOW}1️⃣  配置 Cloudflare 和 D1${NC}"
echo "   cd apps/api"
echo "   vp exec wrangler login"
echo "   vp exec wrangler d1 create my-app-db"
echo "   # 复制 database_id 到 wrangler.toml"
echo ""

echo -e "${YELLOW}2️⃣  安装依赖${NC}"
echo "   cd /home/yaoye/projects/agent/test/vite-plus-project"
echo "   vp install"
echo ""

echo -e "${YELLOW}3️⃣  初始化本地数据库${NC}"
echo "   cd apps/api"
echo "   vp exec wrangler d1 migrations apply my-app-db --local"
echo ""

echo -e "${YELLOW}4️⃣  启动本地开发（2 个终端）${NC}"
echo "   终端 1: cd apps/api && vp exec wrangler dev"
echo "   终端 2: cd apps/web && vp dev"
echo ""

echo -e "${GREEN}祝你开发顺利！ 🎉${NC}"
echo ""
