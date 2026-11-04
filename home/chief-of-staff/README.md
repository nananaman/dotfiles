# Chief of Staff の起動と再開

Chief は依頼を受ける窓口です。
実装や設定変更は別スペースの担当へ任せ、同じ Chief の会話から進捗と成果を確認します。
運用の指示は [AGENTS.md](AGENTS.md) にあります。

## 配置と前提

このガイドの起動例は macOS 用です。
別のPCでは dotfiles を nono の許可範囲内（標準は `~/ghq/github.com/nananaman/dotfiles`）へ取得し、最初に [dotfiles の初回セットアップ](https://github.com/nananaman/dotfiles#セットアップ) を行います。
Herdr の導入と core の初期設定は同じ root README の [Herdr Desktop](https://github.com/nananaman/dotfiles#herdr-desktop) に従います。
Codex の認証はPCごとに本人が行い、認証情報や既存の会話を同期しません。

dotfiles の `home/chief-of-staff/AGENTS.md`、`README.md`、`mise.toml` を、それぞれ `~/chief-of-staff` へ symlink で配置します。
ディレクトリ全体はリンクせず、ローカルの `.codex`、会話、認証情報は dotfiles に取り込みません。
既存ファイルがある場合は、セットアップ前に内容を退避します。
特に既存の `mise.toml` がある場合は上書きせず、内容を確認してから統合します。
初回セットアップ後、取得した dotfiles のルートで Chief の3ファイルだけを配置できます。
リンク元の checkout は配置後も保持します。
起動用の [nono-codex.py](nono-codex.py) は `mise.toml` のリンク先と同じディレクトリから参照するため、既存の3ファイルの配置で動きます。
Python 3.11 以降が必要です。

```sh
mise bootstrap dotfiles apply '~/chief-of-staff/AGENTS.md' '~/chief-of-staff/README.md' '~/chief-of-staff/mise.toml'
```

`HC_SESSION` を指定しなければ、既存 Herdr core の `default` セッションを使います。
`hc --skill`、`herdr-app --skill`、`hc server status` で導入と接続先を確認します。
別の既存セッションを使う場合は、起動時に `HC_SESSION=chief-overnight mise run chief` のように指定します。
core が存在しない、または接続できない場合に、sandbox 内から新しい core を起動して回復しようとしません。

Chief と担当の両方を外側の nono で制限します。
内側の Codex は `--no-daemon --sandbox danger-full-access --ask-for-approval never` に統一し、ファイル、ネットワーク、コマンドの制限を nono が担います。
この Codex の引数を nono なしで使わないでください。
nono 本体、既存の `chouge-codex` profile、認証済みの Codex、Herdr が必要です。
Codex は dotfiles の `~/.local/bin/codex` wrapper を nono 内で明示して起動します。
wrapper が `MISE_CODEX_VERSION`（未指定ならグローバル pin）から実体を選ぶため、起動元の古い PATH にある Codex は使いません。

## Herdr から初めて起動する

ユーザーが選んだ Chief 用の Herdr 端末のシェルで実行します。
初回だけ、自分で配置した `mise.toml` を信頼します。
モデルと effort は Codex の現在の設定を使います。

```sh
cd ~/chief-of-staff
mise trust mise.toml
mise run chief
```

引数なしでは Chief 用の初回 prompt を渡します。
引数がある場合は既定 prompt を加えず、そのまま Codex へ渡します。
モデルと effort を上書きする場合も通常の引数を使えます。

```sh
mise run chief -m gpt-6.1-sol -c 'model_reasoning_effort="high"' '依頼を整理してください。'
```

既定 prompt は [mise.toml](mise.toml)、nono と Codex の起動引数は [nono-codex.py](nono-codex.py) で管理します。

session と接続先は [hc 0.1.17 の paths.rs](https://github.com/herdrdev/herdr-core/blob/ce87721557176f6cddaac1c7aefbf76929923263/crates/herdr-core/src/paths.rs) と [Unix の解決規則](https://github.com/herdrdev/herdr-core/blob/ce87721557176f6cddaac1c7aefbf76929923263/crates/herdr-core/src/platform/unix.rs) に合わせます。
`HC_SESSION` の前後の ASCII 空白を除き、未設定・空値は `default` にします。
この起動scriptでは、名前を英数字と `_ . -` に限定し、`.`、`..`、パス区切りを拒否します。
state は `${XDG_STATE_HOME:-$HOME/.local/state}/herdr-core/<session>` です。
socket は `HC_SOCKET`、hc config の `socket`、`$XDG_RUNTIME_DIR/herdr-core/<session>.sock` の順に選びます。
runtime が未設定・空値なら、既存の `/run/user/<uid>/herdr-core`、次に session の state ディレクトリを使います。
接続先を解決できない config では起動を中止します。
script 自体は core に接続せず、起動・再起動もしません。

state は読取だけ、2つの Unix socket は接続だけを許可します。
`herdr-app` の実行ファイルはアプリの配置先への symlink であるため、その実体の読取も指定します。
この許可は core や app の操作を読取専用に制限するものではありません。
送信、担当起動、表示変更などは会話で許可された範囲に従います。

nono の trace は `--log-file` で一時ファイルへ送り、起動時に `nono log: <パス>` を1行表示します。
ファイルは一意な名前と mode 600 で作り、Git に含めません。不要になったログは削除できます。
子コマンドの stdout・stderr・終了コードと nono の拒否診断は端末に残します。
`--silent` はファイル拒否の診断も消すため使いません。
ファイル拒否は端末の `Sandbox denial`、通信拒否の理由は表示されたログで確認します。

`--suppress-save-prompt "$HOME/.nix-profile"` で、既知の `.nix-profile` 拒否に対する保存提案だけを省きます。
アクセス権と拒否診断は維持し、他のpathの保存提案は抑制しません。
nono 0.68.0 では、対象が存在しない場合や dangling symlink でも起動できることを確認済みです。

```sh
# nono_log に表示されたパスを代入して確認する
rg -n 'proxy request denied' "$nono_log"
```

## 保存済みの get JSON を短く確認する

既に取得した `hc get --json` のJSONを、stdinから[compact-status.py](compact-status.py)へ渡します。
既存の3つの symlink で利用でき、追加配置は不要です。

```sh
cd ~/chief-of-staff
mise --quiet run compact-status < /path/to/captured-get.json
```

`address`、`state`、`status` 全体、`turn`、`exit_code`、`signal`、`reason`、`reported` を1行のJSONで保持します。
トップレベルの `argv`、`screen`、その他の項目は表示しません。
`null`、`0`、`false` は元の値のままで、端末の完了や成功には読み替えません。
対応する入力は hc 0.1.17 の Terminal と Status の形式です。必須8項目は欠落を補完しません。

終了値0は投影の成功を表します。`blocked` や `error` のstatusもそのまま返すため、作業成功の意味ではありません。
入力の `error` objectは内容を保持し、filterのstderrと終了値65で示します。
空入力、不正JSON、重複キー、schema不備もstderrと終了値65で示し、生入力は出力しません。
引数があれば終了値64、stdinの読取失敗は終了値74です。

scriptはstdinの読取と投影だけを行い、taskはそのscriptを起動します。
`hc` の実行やsocket接続は行いません。
sessionや対象の指定、timeout、自動read、wait、retryもありません。
stdinだけでは元のhcのstderr、CLI終了値、timeoutの有無は分かりません。取得時の記録と分けて確認します。
filterの終了値や端末の `exit_code` から、元のhcのCLI終了値を復元しません。
上流のget payload自体は減らず、保存済みJSONから表示する情報だけが減ります。
bytes、lines、呼出数による表示量の比較は、実tokensの測定とは区別します。

引継ぎでは元の依頼や画面を再掲せず、次の5項目を残します。
成果根拠に短いstatusと参照先、検証の結果、未実施項目やエラーを含めます。

```text
目的: 状態表示と引継ぎの重複を減らす。
範囲: stdinのJSON投影と既存mise task。接続は行わない。
完了条件: 必須8項目と失敗情報を保持し、接続0で表示する。
成果根拠: <commit>、<file:line>、<statusと検証結果・未実施項目>。
次の一手: <担当と具体的な操作>。
```

## 応答しない core を既存 sample で確認する

対象 core が応答しない場合は、`status`、`get`、`run` などの接続を重ねず、許可済みの既存資料で確認します。
既に取得した macOS sample がある場合は、読むことを許可された通常ファイルを明示します。

```sh
cd ~/chief-of-staff
mise run inspect-sample /path/to/first-sample.txt /path/to/second-sample.txt
```

[inspect-sample.py](inspect-sample.py) は入力順に1行のJSONを返します。
PID、観測時刻、launch time、herdr-core の UUID、主threadの観測frameを抽出し、連続する同じframeは件数でまとめます。
入力path、生のsample、アドレス、他threadは出力しません。
既存の3つの symlink から利用でき、追加配置は不要です。

対応は今回確認済みの macOS `/usr/bin/sample` report version 7 の形式に限ります。
frameは `start`、herdr-core の無名symbol、`__private_getcwd`、`__getcwd`、`open$NOCANCEL`、`__open_nocancel` を認識します。
無名symbolは `herdr-core (unknown symbol)` と表示し、呼出元の関数は特定しません。
未対応形式、欠落、未知frame、読取拒否は `unknown` または `issues` に残し、stderrと終了値1で示します。
読取不能でも必須5項目を `unknown` で保持します。入力省略は終了値2です。

scriptは明示したファイルだけを読み、`hc`、`ps`、`sample`、`log` を実行しません。
defaultのpath探索、socket接続、core起動、再現実行もしません。
同一性を比較するときはPIDだけでなくlaunch time、UUID、観測時刻を確認します。
sampleの観測から現在の生存、根本原因、権限不足は判定しません。
読取を拒否された場合は対象とエラーを報告し、追加権限や外側core経由の `hc exec` で迂回しません。
既存coreの停止、再起動、設定やOS Privacyの変更は、この診断には含めません。

## 同じ会話を再開する

同じ会話を二重に起動しません。
既存 Chief の終了と再開はユーザーが行い、担当から窓口の端末や Herdr 全体を停止しません。
Chief 用端末のシェルで、既存の Chief の会話 ID を指定します。
ID を省略すると picker で会話を選べます。
`--last` は担当の別会話を選ぶ可能性があるため使いません。

```sh
cd ~/chief-of-staff
mise run chief resume <会話ID>
```

`~/chief-of-staff/.codex/config.toml` の `approval_policy="on-request"` と `approvals_reviewer="auto_review"` は以前の方式のローカル設定です。
上記では CLI の `--ask-for-approval never` が優先されるため、内側の承認要求と自動レビューは使いません。
設定ファイルは削除、同期せずに残します。
`--no-daemon` は Codex の処理を nono と Herdr の端末内に置くため、初回起動と再開の両方に必要です。
既に nono 内の端末で nono を二重に起動しません。

## 別スペースの担当を起動する

`hc run` と `hc exec` の実行主体は、親 Chief とは別の Herdr core です。
親の nono 制限や環境変数があるだけでは、core が作るプロセスは制限されません。
担当を起動する実 argv に `nono run` を含めます。
目的、担当範囲、作業場所、完了条件、報告先を依頼文に入れます。

Chief は依頼内容と対象リポジトリから worktree の実パスを確認して `task_dir` に代入します。
`herdr-app ls` の結果と会話内の許可から別スペースの実 ID を選び、`worker_space` に代入します。
合意済みの目的、担当範囲、完了条件を含む依頼文を `task_prompt` に代入してから、以下を実行します。
`hc_state` と `hc_socket` には、使用する `HC_SESSION`、XDG 環境変数、hc config と実接続先から確認したパスを代入します。
値を推測したり、例を実行するためだけに人間の入力を待ったりしません。
この例は既存スペースを使い、新しいスペースを作りません。

```sh
: "${HC_TERMINAL_ID:?Chief を --no-daemon で起動して窓口の実 ID を確認してください}"
: "${task_dir:?確認した対象 worktree の実パスを代入してください}"
: "${worker_space:?確認した別スペースの実 ID を代入してください}"
: "${task_prompt:?合意済みの依頼文を代入してください}"
: "${hc_state:?確認した session の state ディレクトリを代入してください}"
: "${hc_socket:?確認した core の Unix socket を代入してください}"
: "${MISE_CODEX_VERSION:?確認した Codex の版を代入してください}"
nono_log=$(mktemp "${TMPDIR:-/tmp}/chief-nono.XXXXXX")
printf 'nono log: %s\n' "$nono_log" >&2
hc run --bg --cwd "$task_dir" --label "herdr.space=$worker_space" \
  env HC_SESSION="${HC_SESSION:-default}" MISE_CODEX_VERSION="$MISE_CODEX_VERSION" \
  nono run --profile chouge-codex --log-file "$nono_log" \
  --suppress-save-prompt "$HOME/.nix-profile" \
  --workdir "$task_dir" --allow-cwd \
  --read "$hc_state" --allow-unix-socket "$hc_socket" \
  --allow-unix-socket "$HOME/.config/herdr-app/herdr-app.sock" \
  --read-file "$(command -v herdr-app)" \
  -- "$HOME/.local/bin/codex" --no-daemon --sandbox danger-full-access --ask-for-approval never \
  -C "$task_dir" -m gpt-6.1-sol -c 'model_reasoning_effort="high"' \
  "$task_prompt 窓口は $HC_TERMINAL_ID。完了または進められない時は hc send $HC_TERMINAL_ID で結果と根拠のパスを報告してください。追加担当は起動しないでください。"
```

`MISE_CODEX_VERSION` は wrapper に渡し、core が持つ PATH に依存せず版を選びます。
担当の版は起動結果で確認します。

起動結果の `first_message.sent` と端末の実 ID を確認します。
`hc get` と `hc read` で状態と内容を確かめ、`hc wait` で待ちます。
担当起動、ファイルのリンク、`NONO_CAP_FILE` の存在だけを制限が働いた証拠にせず、通常コマンドで許可先の書込みと範囲外の拒否を確認します。
nono が拒否した場合は必要な対象だけを調べ、裸の Codex 起動や sandbox の全解除で代替しません。

Herdr の窓が閉じていて hidden 端末の利用が許可されている場合は、`hc get`・`hc read`・`hc wait` で確認します。
窓・スペース・フォーカスを変更しません。`hc wait` が timeout で対象が working なら、同じ画面を繰り返し read せず待ちます。
報告、状態や差分の変化、blocked・error があるときに内容を確認します。

元の checkout に未保存の差分があれば、stash や pull をせず、許可された別 worktree を使います。
応答しない既存 core を無断で修復・停止しません。
