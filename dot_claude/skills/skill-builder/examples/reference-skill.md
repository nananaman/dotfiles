# 参照コンテンツ型Skillの例

このファイルは、参照コンテンツ型skillのサンプルです。

## 例1: API規約

```yaml
---
name: api-conventions
description: このコードベースのAPI設計パターンと規約。APIエンドポイントを作成・修正する際に使用。
user-invocable: false
---

# API規約

## エンドポイント命名

RESTful規則に従う:
- リソース名は複数形: `/users`, `/posts`, `/comments`
- IDは名詞の単数形: `/users/:userId`, `/posts/:postId`
- アクションは動詞: `/users/:userId/activate`, `/posts/:postId/publish`

## リクエスト検証

すべてのエンドポイントで入力を検証:

```typescript
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(['user', 'admin'])
});

export async function createUser(req: Request) {
  const data = createUserSchema.parse(req.body);
  // ...
}
```

## エラーフォーマット

一貫したエラーレスポンス:

```typescript
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": {
      "field": "email",
      "issue": "Invalid email format"
    }
  }
}
```

ステータスコード:
- 400: バリデーションエラー
- 401: 認証エラー
- 403: 権限エラー
- 404: リソース未発見
- 500: サーバーエラー

## 認証

Bearer token認証を使用:

```typescript
Authorization: Bearer <token>
```

ミドルウェアで検証:

```typescript
export const requireAuth = async (req: Request) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) throw new ApiError(401, 'Authentication required');

  const user = await verifyToken(token);
  req.user = user;
};
```
```

**特徴**:
- `user-invocable: false`: バックグラウンド知識として常に利用可能
- 簡潔で具体的な例
- プロジェクト固有のパターン
- Claudeが既に知っている一般論は省略

## 例2: コーディングスタイル

```yaml
---
name: coding-style
description: プロジェクトのコーディングスタイルとパターン。コードを書く際に常に参照。
user-invocable: false
---

# コーディングスタイル

## React コンポーネント

### ファイル構成

```typescript
// UserProfile.tsx
import { FC } from 'react';
import { User } from '@/types';
import styles from './UserProfile.module.css';

interface UserProfileProps {
  user: User;
  onEdit?: () => void;
}

export const UserProfile: FC<UserProfileProps> = ({ user, onEdit }) => {
  return (
    <div className={styles.container}>
      <h2>{user.name}</h2>
      {onEdit && <button onClick={onEdit}>Edit</button>}
    </div>
  );
};
```

### 命名規則

- コンポーネント: PascalCase (`UserProfile`, `PostList`)
- Hooks: `use` prefix (`useAuth`, `usePosts`)
- ユーティリティ: camelCase (`formatDate`, `validateEmail`)
- 定数: UPPER_SNAKE_CASE (`API_URL`, `MAX_RETRIES`)

### 状態管理

ローカル状態: `useState`
グローバル状態: Context API
サーバー状態: React Query

```typescript
// ローカル
const [isOpen, setIsOpen] = useState(false);

// グローバル
const { user } = useAuth();

// サーバー
const { data: posts } = useQuery('posts', fetchPosts);
```

## TypeScript

### 型定義の配置

- 共通型: `src/types/index.ts`
- コンポーネント固有: 同じファイル内
- API型: `src/types/api.ts`

### 型 vs インターフェース

オブジェクト形状: `interface`
ユニオン・インターセクション: `type`

```typescript
// 推奨
interface User {
  id: string;
  name: string;
}

type UserRole = 'admin' | 'user' | 'guest';
type ApiResponse<T> = { data: T } | { error: string };
```
```

**特徴**:
- プロジェクト固有の規約に焦点
- 具体的なコード例
- 説明は最小限
- すぐに適用可能

## 例3: データベーススキーマ

```yaml
---
name: db-schema
description: データベーススキーマとマイグレーションパターン。データベース変更を行う際に参照。
user-invocable: false
---

# データベーススキーマ

## テーブル構造

### users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'user',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### posts
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_published ON posts(published);
```

## マイグレーション規則

ファイル名: `YYYYMMDDHHMMSS_description.sql`

例: `20260130120000_add_posts_table.sql`

必ず含める:
- UP migration（変更適用）
- DOWN migration（変更取り消し）

```sql
-- UP
CREATE TABLE posts (...);

-- DOWN
DROP TABLE posts;
```
```

**特徴**:
- 実際のスキーマ定義
- マイグレーションパターン
- プロジェクト固有の規則

## 使用方法

これらの例を参考に、自分のプロジェクトに合わせた参照コンテンツ型skillを作成できます。

**ポイント**:
1. `user-invocable: false` で常に利用可能に
2. 具体的なコード例を中心に
3. プロジェクト固有の情報のみ
4. 簡潔に保つ（500行未満）
