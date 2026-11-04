# Chief of Staff の起動と再開

Chief は依頼を受ける窓口です。
実装や設定変更は別スペースの担当へ任せ、同じ Chief の会話から進捗と成果を確認します。
運用の指示は [AGENTS.md](AGENTS.md) にあります。

## 配置と前提

このガイドの起動例は macOS 用です。
別のPCでは dotfiles を任意の場所へ取得し、最初に [dotfiles の初回セットアップ](https://github.com/nananaman/dotfiles#セットアップ) を行います。
Herdr の導入と core の初期設定は同じ root README の [Herdr Desktop](https://github.com/nananaman/dotfiles#herdr-desktop) に従います。
Codex の認証はPCごとに本人が行い、認証情報や既存の会話を同期しません。

dotfiles の `home/chief-of-staff/AGENTS.md` と `README.md` を、それぞれ `~/chief-of-staff` へ symlink で配置します。
ディレクトリ全体はリンクせず、ローカルの `.codex`、会話、認証情報は dotfiles に取り込みません。
既存ファイルがある場合は、セットアップ前に内容を退避します。
初回セットアップ後、取得した dotfiles のルートで Chief の2ファイルだけを配置できます。
リンク元の checkout は配置後も保持します。

```sh
mise bootstrap dotfiles apply '~/chief-of-staff/AGENTS.md' '~/chief-of-staff/README.md'
```

以下は既存 Herdr core の `default` セッションを使います。
`hc --skill`、`herdr-app --skill`、`hc server status` で導入と接続先を確認します。
別の `HC_SESSION` や state directory を使う場合は、実際の接続先に合わせて下記のパスを変更します。
core が存在しない、または接続できない場合に、sandbox 内から新しい core を起動して回復しようとしません。

Chief と担当の両方を外側の nono で制限します。
内側の Codex は `--no-daemon --sandbox danger-full-access --ask-for-approval never` に統一し、ファイル、ネットワーク、コマンドの制限を nono が担います。
この Codex の引数を nono なしで使わないでください。
nono 本体、既存の `chouge-codex` profile、認証済みの Codex、Herdr が必要です。

## Herdr から初めて起動する

ユーザーが選んだ Chief 用の Herdr 端末のシェルで実行します。
モデルと effort は現在の設定を確認してから指定します。
以下は `gpt-6.1-sol` と `high` を使う例です。

```sh
nono run --profile chouge-codex \
  --workdir "$HOME/chief-of-staff" --allow-cwd \
  --read "$HOME/.local/state/herdr-core/default" \
  --allow-unix-socket "$HOME/.local/state/herdr-core/default/default.sock" \
  --allow-unix-socket "$HOME/.config/herdr-app/herdr-app.sock" \
  --read-file "$(command -v herdr-app)" \
  -- codex --no-daemon --sandbox danger-full-access --ask-for-approval never \
  -C "$HOME/chief-of-staff" -m gpt-6.1-sol -c 'model_reasoning_effort="high"' \
  'AGENTS.md と hc --skill を読み、Chief of Staff として依頼を受けてください。'
```

state は読取だけ、2つの Unix socket は接続だけを許可します。
`herdr-app` の実行ファイルはアプリの配置先への symlink であるため、その実体の読取も指定します。
この許可は core や app の操作を読取専用に制限するものではありません。
送信、担当起動、表示変更などは会話で許可された範囲に従います。

## 同じ会話を再開する

同じ会話を二重に起動しません。
既存 Chief の終了と再開はユーザーが行い、担当から窓口の端末や Herdr 全体を停止しません。
Chief 用端末のシェルで以下を実行し、picker から既存の Chief の会話を選びます。
会話 ID が分かる場合は `resume` の後に指定できます。
`--last` は担当の別会話を選ぶ可能性があるため使いません。

```sh
nono run --profile chouge-codex \
  --workdir "$HOME/chief-of-staff" --allow-cwd \
  --read "$HOME/.local/state/herdr-core/default" \
  --allow-unix-socket "$HOME/.local/state/herdr-core/default/default.sock" \
  --allow-unix-socket "$HOME/.config/herdr-app/herdr-app.sock" \
  --read-file "$(command -v herdr-app)" \
  -- codex --no-daemon --sandbox danger-full-access --ask-for-approval never \
  -C "$HOME/chief-of-staff" -m gpt-6.1-sol -c 'model_reasoning_effort="high"' resume
```

`~/chief-of-staff/.codex/config.toml` の `approval_policy="on-request"` と `approvals_reviewer="auto_review"` は以前の方式のローカル設定です。
上記では CLI の `--ask-for-approval never` が優先されるため、内側の承認要求と自動レビューは使いません。
設定ファイルは削除、同期せずに残します。
`--no-daemon` は Codex の処理を nono と Herdr の端末内に置くため、初回起動と再開の両方に必要です。
既に nono 内の端末で nono を二重に起動しません。

## 別スペースの担当を起動する

`hc run` と `hc exec` の実行主体は、親 Chief とは別の Herdr core です。
親の nono 制限や環境変数があるだけでは、core が作るプロセスは制限されません。
担当を起動する実 argv に nono を含めます。
目的、担当範囲、作業場所、完了条件、報告先を依頼文に入れます。

Chief は依頼内容と対象リポジトリから worktree の実パスを確認して `task_dir` に代入します。
`herdr-app ls` の結果と会話内の許可から別スペースの実 ID を選び、`worker_space` に代入します。
合意済みの目的、担当範囲、完了条件を含む依頼文を `task_prompt` に代入してから、以下を実行します。
値を推測したり、例を実行するためだけに人間の入力を待ったりしません。
この例は既存スペースを使い、新しいスペースを作りません。

```sh
: "${HC_TERMINAL_ID:?Chief を --no-daemon で起動して窓口の実 ID を確認してください}"
: "${task_dir:?確認した対象 worktree の実パスを代入してください}"
: "${worker_space:?確認した別スペースの実 ID を代入してください}"
: "${task_prompt:?合意済みの依頼文を代入してください}"
hc run --bg --cwd "$task_dir" --label "herdr.space=$worker_space" \
  nono run --profile chouge-codex --workdir "$task_dir" --allow-cwd \
  --read "$HOME/.local/state/herdr-core/default" \
  --allow-unix-socket "$HOME/.local/state/herdr-core/default/default.sock" \
  --allow-unix-socket "$HOME/.config/herdr-app/herdr-app.sock" \
  --read-file "$(command -v herdr-app)" \
  -- codex --no-daemon --sandbox danger-full-access --ask-for-approval never \
  -C "$task_dir" -m gpt-6.1-sol -c 'model_reasoning_effort="high"' \
  "$task_prompt 窓口は $HC_TERMINAL_ID。完了または進められない時は hc send $HC_TERMINAL_ID で結果と根拠のパスを報告してください。追加担当は起動しないでください。"
```

起動結果の `first_message.sent` と端末の実 ID を確認します。
`hc get` と `hc read` で状態と内容を確かめ、`hc wait` で待ちます。
担当起動、ファイルのリンク、`NONO_CAP_FILE` の存在だけを制限が働いた証拠にせず、通常コマンドで許可先の書込みと範囲外の拒否を確認します。
nono が拒否した場合は必要な対象だけを調べ、裸の Codex 起動や sandbox の全解除で代替しません。
