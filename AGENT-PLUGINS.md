# APMでpstackと補完skillを管理する

これは未適用の候補です。正本は `home/.apm/apm.yml`、通常同期は `mise run apm-sync`（APMのfull installと起動hookの参照補正） です。
別のnative marketplace宣言・同期manager・恒久的なskill非表示routerは持ちません。

## 配布するもの

- pstack: `michael-denyer/pstack-claude/plugins/pstack#5851c89613e2ddc3a6b7f4af02a42363b30ef8d3`、version0.9.114。
- 本人の補完13件: `~/ghq/github.com/nananaman/skills/plugin/skills/<name>`。正本0.3.0へ反映してから同期する。
- textlint、Orca、show-meの既存依存とtargetsは維持する。
- 旧汎用14件はAPM依存から除く。prototypeは元のAPM依存にはなく、本人配布treeでは計15件を除去している。

APMはpluginのskills・agents・hook定義を各targetへ展開する。native pluginとしての登録、plugin名前空間、marketplace一覧は別の機能であり、開発フローの必須条件にはしない。
共通AGENTSはpoteto-modeと現在検出されるskillを使う方針だけを持つ。モデル・effortは実行環境のpstack-models.mdに置く。

## 通常の操作

```sh
mise run apm-plan
mise run apm-sync
```

単一packageの追加だけでは旧依存のcleanupにならない。旧依存を除いたmanifest全体を同期し、lockの所有記録に沿って消えた配置を確認する。
APMは手編集された配置や所有不明のファイルを保持する場合があるため、成功表示だけで旧入口が消えたとは判断しない。残った対象を確認し、無差別にdirectoryを削除しない。

## 初回切替だけの作業

1. shared AGENTS・APM manifest/lock・対象config値・既存link・ユーザー変更をprivateに保存する。旧maintenance pinとCodex0.159.3の変更は保管し、無関係なmise変更を巻き込まない。
2. 旧maintenanceを直接呼ぶ日次自動化の扱いを別途承認する。旧入口を除去した後も動くとは扱わない。
3. 旧APM汎用依存を除いて同期し、本人source0.3.0と新manifestを反映する。必要なら旧tdd配置の除去とpstack追加を2回のAPM同期に分け、--forceで衝突を解決しない。
4. 別登録の `nananaman-skills@nananaman-skills` はnative設定のenabledをfalseにする。APMはこの登録を所有しない。cacheは復旧用に残す。
5. 旧APM配置を二重表示しないための既存skills.config無効化行は、新APM配布のtdd・補完skillも隠す。対象の旧所有path行だけを取り除き、無関係な個別設定を残す。
6. subagentが必要な環境でmulti_agent/agentsを有効にし、同時担当数を2にする。共有AGENTSと必要な設定linkは新配置を確認してから反映する。bootstrap全体を切替に使わない。
7. 実際に検出される名前・resources・モデル表・hookを確認する。新hookの信頼・実行と小さいモデル試験は、その操作への承認後に限る。

対象config値の例（全configをこの内容で上書きしない）:

```toml
[plugins."nananaman-skills@nananaman-skills"]
enabled = false
[features]
multi_agent = true
[agents]
enabled = true
max_threads = 2
```

## 起動hookの参照補正

APM0.29.0はpstackのskills・agents・hook定義を展開するが、移設したshell scriptへCLAUDE_PLUGIN_ROOTを渡さない。
そのため `apm-sync` は既存の部分補正を先に回復し、full install後に `scripts/apm-pstack-hooks.py --apply` を呼び、pstackのSessionStartコマンドだけにAPM cacheのrootを渡す。
スクリプトは固定0.9.114のreader・context・hookのhash、APM所有記録、現存コマンドを照合し、変更済みなら上書きせず失敗する。
コマンドとAPM sidecarを一緒に補正する。途中中断は次のapm-syncのinstall前に回復し、二重登録を防ぐ。ClaudeのCLAUDE_CONFIG_DIR指定にも従う。配布script・APM lock・他のhook・信頼設定は変更しない。

```sh
# install済みの補正予定だけを確認。hookは実行しない。
python3 scripts/apm-pstack-hooks.py
```

これはAPM0.29.0と固定pstack向けの互換処理で、別のinstaller・依存manager・model routerではない。
pstackまたはAPMを更新するときはこの補正の要否とhashを再確認する。更新失敗後に通常sessionを開始しない。
APMを直接installした場合も補正が必要なので、dotfiles管理下ではapm-syncを入口にする。
新しいコマンドへのhook信頼・実行は、通常環境の切替で別途承認する。

## 隔離検証と残る確認

固定sourceの671 fileをGit objectと照合し、隔離HOMEへAPM0.29.0で展開した。67 skillsと4 agents、SessionStart定義を確認した。
第三者hookの比較は各5秒上限で2回だけ実施し、生成コマンドは0.342秒でroot未定義により失敗、root明示は0.023秒で成功した。出力は固定contextとbyte単位で一致した。
ネットワーク・モデル・認証情報は使っていない。補正後の実pstack hookを追加実行したとは扱わない。
自作の無害なfixtureで、補正のpreview・冪等性・spaceを含むpath・手編集保護と、実APMによる再同期時の重複防止を検証する。

- full installで除去済みskillの管理下fileがcleanupされ、手置きskillは残る。
- pstack:<name>参照はAPMで自動改名されない。同じ配布元の検出済みbare skill/agent名へ対応付ける共通指示を使う。Claudeのpstack:poteto-agentを含むモデル上の実呼出し受入は未実施。
- APM外の旧native登録と個別skill非表示設定は別途整理する。共通指示の変更だけでは無効にならない。

## 復旧

対象だけをprivate backupと旧source/cacheから戻し、APM所有の配置はmanifestから再同期する。
pstackを外す場合は、依存を単に削除する前にAPM uninstallでhook定義も除去する。APM0.29.0のfull installだけでは除去済みpackageのmerged hookが残る場合がある。
旧native pluginを再有効化する場合は旧source/cacheを確認し、新APMの重複配置と個別hook状態を整理する。
無関係なplugin・hook trust・ユーザー変更・自動化を一括復旧しない。merge済みGitHub履歴を自動で書き戻さない。
