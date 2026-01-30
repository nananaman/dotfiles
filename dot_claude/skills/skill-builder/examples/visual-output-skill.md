# 視覚的出力型Skillの例

このファイルは、視覚的出力型skillのサンプルです。外部スクリプトを活用して複雑な処理や可視化を行います。

## 例1: コードベース可視化

```yaml
---
name: visualize-codebase
description: コードベースの構造をツリー形式やグラフで可視化。コードベース構造、ディレクトリツリー、依存関係グラフを表示する際に使用。
allowed-tools:
  - Bash
  - Read
---

# コードベース可視化

## ディレクトリツリー

プロジェクトの構造を可視化:

!`tree -L 3 -I 'node_modules|.git|dist|build' --dirsfirst`

## ファイル統計

```bash
#!/bin/bash
echo "## ファイル統計"
echo ""
echo "| 種類 | 数 | 行数 |"
echo "|------|-----|------|"

# TypeScript
ts_count=$(find src -name "*.ts" -o -name "*.tsx" | wc -l)
ts_lines=$(find src -name "*.ts" -o -name "*.tsx" | xargs wc -l | tail -1 | awk '{print $1}')
echo "| TypeScript | $ts_count | $ts_lines |"

# JavaScript
js_count=$(find src -name "*.js" -o -name "*.jsx" | wc -l)
js_lines=$(find src -name "*.js" -o -name "*.jsx" | xargs wc -l | tail -1 | awk '{print $1}')
echo "| JavaScript | $js_count | $js_lines |"

# CSS
css_count=$(find src -name "*.css" -o -name "*.scss" | wc -l)
css_lines=$(find src -name "*.css" -o -name "*.scss" | xargs wc -l | tail -1 | awk '{print $1}')
echo "| CSS | $css_count | $css_lines |"
```

## 依存関係グラフ

package.jsonから依存関係を抽出:

!`jq -r '.dependencies, .devDependencies | to_entries[] | "\(.key)@\(.value)"' package.json | sort`

## 最近の変更

Gitコミット履歴から最近のアクティビティを表示:

```bash
git log --since="1 week ago" --pretty=format:"%h - %an, %ar : %s" --graph
```
```

**特徴**:
- 複数のコマンドラインツールを組み合わせ
- 動的コンテキスト挿入でリアルタイム情報を取得
- マークダウンテーブルやグラフでの可視化

## 例2: テストカバレッジレポート

```yaml
---
name: coverage-report
description: テストカバレッジを実行し、視覚的なレポートを生成。カバレッジ、テストカバレッジ、コードカバレッジを確認する際に使用。
allowed-tools:
  - Bash
  - Read
  - Write
---

# テストカバレッジレポート

## カバレッジ実行

```bash
npm run test:coverage
```

## 結果の解析

coverage/coverage-summary.jsonから統計を抽出:

!`cat coverage/coverage-summary.json | jq -r '
  .total |
  "## 全体カバレッジ\n\n| メトリック | パーセンテージ | カバー済み/合計 |\n|----------|--------------|----------------|\n| 文 | \(.statements.pct)% | \(.statements.covered)/\(.statements.total) |\n| ブランチ | \(.branches.pct)% | \(.branches.covered)/\(.branches.total) |\n| 関数 | \(.functions.pct)% | \(.functions.covered)/\(.functions.total) |\n| 行 | \(.lines.pct)% | \(.lines.covered)/\(.lines.total) |"
'`

## カバレッジが低いファイル

80%未満のファイルを抽出:

```bash
#!/bin/bash
echo "## カバレッジが低いファイル (80%未満)"
echo ""

jq -r '
  to_entries[] |
  select(.key != "total") |
  select(.value.statements.pct < 80) |
  "- \(.key): \(.value.statements.pct)%"
' coverage/coverage-summary.json | sort -t: -k2 -n
```

## 推奨アクション

カバレッジが低いファイルに対して:
1. テストケースの追加を推奨
2. 重要度の高いファイルを優先
3. 目標カバレッジ: 80%以上

## HTMLレポート

詳細なHTMLレポートを開く:

```bash
open coverage/lcov-report/index.html
```
```

**特徴**:
- JSONデータの解析と可視化
- jqを使った高度なデータ処理
- アクションアイテムの提示

## 例3: Git履歴分析

```yaml
---
name: git-analytics
description: Gitリポジトリの履歴を分析し、統計情報を表示。コミット統計、貢献者分析、コード変更履歴を確認する際に使用。
allowed-tools:
  - Bash
---

# Git履歴分析

## コミット統計

### 全期間

```bash
#!/bin/bash
echo "## コミット統計"
echo ""
total=$(git rev-list --all --count)
echo "総コミット数: $total"
echo ""

echo "### 期間別コミット数"
echo ""
echo "| 期間 | コミット数 |"
echo "|------|-----------|"
echo "| 今日 | $(git log --since='midnight' --oneline | wc -l) |"
echo "| 今週 | $(git log --since='1 week ago' --oneline | wc -l) |"
echo "| 今月 | $(git log --since='1 month ago' --oneline | wc -l) |"
echo "| 今年 | $(git log --since='1 year ago' --oneline | wc -l) |"
```

### 貢献者別

```bash
echo ""
echo "### トップ貢献者"
echo ""
git shortlog -sn --all | head -10 | awk '{print "- " $2 " " $3 ": " $1 " コミット"}'
```

## ファイル変更頻度

最も頻繁に変更されるファイル:

```bash
echo ""
echo "## 最も変更されたファイル"
echo ""
git log --all --format='format:' --name-only | \
  grep -v '^$' | \
  sort | \
  uniq -c | \
  sort -rn | \
  head -20 | \
  awk '{print "- " $2 ": " $1 " 回"}'
```

## 言語別コード行数の推移

過去1年間の言語別行数変化:

```bash
#!/bin/bash
echo ""
echo "## 言語別コード行数（現在）"
echo ""

# cloc がインストールされている場合
if command -v cloc &> /dev/null; then
  cloc src --md
else
  echo "clocがインストールされていません"
  echo "インストール: brew install cloc"
fi
```

## ブランチ統計

```bash
echo ""
echo "## ブランチ情報"
echo ""
echo "アクティブブランチ数: $(git branch -a | wc -l)"
echo ""
echo "### 最近のブランチ"
git for-each-ref --sort=-committerdate refs/heads/ \
  --format='- %(refname:short): %(committerdate:relative)' | \
  head -10
```

## コード変更のホットスポット

```bash
echo ""
echo "## コード変更のホットスポット（過去3ヶ月）"
echo ""
git log --since='3 months ago' --pretty=format: --name-only | \
  sort | \
  uniq -c | \
  sort -rg | \
  head -10 | \
  awk '{printf "- %s: %d 回変更\n", $2, $1}'
```
```

**特徴**:
- 複数のGitコマンドを組み合わせ
- AWK/sedなどのテキスト処理ツール活用
- 統計情報の可視化

## 例4: パフォーマンスベンチマーク

```yaml
---
name: benchmark
description: アプリケーションのパフォーマンスベンチマークを実行し、結果を可視化。ベンチマーク、パフォーマンステスト、速度測定を行う際に使用。
disable-model-invocation: true
allowed-tools:
  - Bash
  - Write
---

# パフォーマンスベンチマーク

## ベンチマーク実行

```bash
npm run benchmark
```

## 結果の解析

ベンチマーク結果をJSONから抽出:

!`cat benchmark-results.json | jq -r '
  .benchmarks[] |
  "### \(.name)\n\n- 平均: \(.mean)ms\n- 中央値: \(.median)ms\n- 最小: \(.min)ms\n- 最大: \(.max)ms\n- 標準偏差: \(.stddev)ms\n"
'`

## 過去との比較

前回のベンチマーク結果と比較:

```bash
#!/bin/bash
if [ -f "benchmark-previous.json" ]; then
  echo "## 前回との比較"
  echo ""

  # 差分を計算
  jq -s '
    .[0].benchmarks as $current |
    .[1].benchmarks as $previous |
    $current | to_entries[] |
    . as $c |
    ($previous[] | select(.name == $c.value.name)) as $p |
    {
      name: $c.value.name,
      current: $c.value.mean,
      previous: $p.mean,
      diff: (($c.value.mean - $p.mean) / $p.mean * 100)
    } |
    "- \(.name): \(.diff | if . > 0 then "🔴 +\(.)" else "🟢 \(.)" end)%"
  ' benchmark-results.json benchmark-previous.json

  # 現在の結果を保存
  cp benchmark-results.json benchmark-previous.json
else
  echo "前回のベンチマーク結果がありません"
  cp benchmark-results.json benchmark-previous.json
fi
```

## グラフ生成

gnuplotを使用してグラフ生成:

```bash
#!/bin/bash
# データ準備
jq -r '.benchmarks[] | "\(.name) \(.mean)"' benchmark-results.json > benchmark.dat

# gnuplotスクリプト
cat > benchmark.gnuplot <<EOF
set terminal png size 800,600
set output 'benchmark.png'
set title 'ベンチマーク結果'
set ylabel '時間 (ms)'
set xlabel 'テスト'
set style fill solid
plot 'benchmark.dat' using 2:xtic(1) with boxes title 'Mean Time'
EOF

gnuplot benchmark.gnuplot
echo "グラフを生成しました: benchmark.png"
```

## 推奨アクション

パフォーマンスが悪化している場合:
1. プロファイリングを実行
2. ボトルネックを特定
3. 最適化を実施
4. 再度ベンチマーク
```

**特徴**:
- 外部ツール（gnuplot）の活用
- データの保存と比較
- グラフ生成

## スクリプトの活用

視覚的出力型skillでは、専用のスクリプトファイルを作成することも推奨:

### scripts/visualize.sh

```bash
#!/bin/bash
# コードベース可視化スクリプト

echo "# コードベース構造"
echo ""

# ディレクトリツリー
echo "## ディレクトリ構造"
echo ""
echo "\`\`\`"
tree -L 3 -I 'node_modules|.git' --dirsfirst
echo "\`\`\`"
echo ""

# ファイル統計
echo "## ファイル統計"
# ... (処理)
```

### SKILL.mdから呼び出し

```markdown
!`./scripts/visualize.sh`
```

## 使用方法

これらの例を参考に、自分のプロジェクトに合わせた視覚的出力型skillを作成できます。

**ポイント**:
1. 外部スクリプトやツールを積極的に活用
2. 動的コンテキスト挿入でリアルタイムデータを取得
3. マークダウンテーブルやグラフで可視化
4. jq, awk, sedなどのテキスト処理ツールを駆使
5. 複雑な処理は専用スクリプトファイルに分離
