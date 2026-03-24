# Docs/Slides コマンド

## Google Docs

### 内容の取得
```bash
# Google Docの内容をテキストで表示
gog docs cat <documentId>

# メタデータ取得
gog docs info <documentId>
```

### エクスポート
```bash
# PDF/DOCX/TXTへのエクスポート
gog docs export <documentId> --format pdf
gog docs export <documentId> --format docx
gog docs export <documentId> --format txt
```

### 作成とコピー
```bash
# Google Doc作成
gog docs create "Document Title"

# コピー
gog docs copy <documentId> "Copy Title"
```

## Google Slides

### エクスポート
```bash
# Google Slidesエクスポート
gog slides export <presentationId> --format pptx
gog slides export <presentationId> --format pdf
```

## Microsoft Officeファイル

### 重要な注意点
Word文書(.docx)やPowerPoint(.pptx)ファイルは、Google DriveにアップロードされたMicrosoft Office形式のファイルです。これらは `gog docs` や `gog slides` コマンドでは操作できません。

```bash
# Word文書(.docx)のダウンロード
gog drive download <fileId> --out ./document.docx

# PowerPoint(.pptx)のダウンロード
gog drive download <fileId> --out ./presentation.pptx
```

## ファイル形式の確認

```bash
# ファイル情報を取得してMIME Typeを確認
gog drive search "name contains 'document'" --json | \
  jq '.files[] | {name, mimeType, id}'
```

**Google Docs**: `application/vnd.google-apps.document`
**Word文書**: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`

**Google Slides**: `application/vnd.google-apps.presentation`
**PowerPoint**: `application/vnd.openxmlformats-officedocument.presentationml.presentation`
