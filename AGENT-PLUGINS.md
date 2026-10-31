# Agent pluginをdotfilesで管理する

これは未適用の候補です。Codexはpstack native一式を主入口にし、本人の補完13件をnative pluginとして使います。
APMは他clientの互換viewと、textlint・Orca等の依存を維持します。

## clientごとの配置

| client | 開発の入口 | 本人skill | 今回変えるもの |
| --- | --- | --- | --- |
| Codex | native pstack:poteto-mode | 補完0.3.0の13件 | native登録、旧plugin/旧loose24件のdiscovery、AGENTS/model設定、個別hook信頼 |
| Claude | 従来のimplement | APMの旧24件 | 取得元を固定commitへ変更し、名前・本文・targetを維持 |
| Pi等の共有skill consumer | 従来の入口 | APMの旧24件 | 同じ固定viewを維持。pstack移行は別途検証する |

APM targetsはclaude/codex/agent-skillsのままです。
Codexのnativeには全pstack treeを登録し、APMからpstackを展開しません。
旧native pluginと旧loose skillはCodexの設定でdiscoveryから除きます。Claude等のファイルは削除しません。
APMの互換viewは他clientの移行まで更新が固定されるため、Codexの補完規約の更新が自動で他clientへ届く構成ではありません。

## 正本と所有範囲

- `agent-plugins.toml`: native source、full SHA/local path、期待version、Codexで隠す旧plugin/旧APM skill名。
- `home/.apm/apm.yml`: APM依存と互換viewの参照先。本人23件は導入済み0.2.0 baselineの`d25aec07e3fd2695165e274330afa7d183ba3e6a`、skill-maintenanceは既存ユーザー変更の`8f1e4a66cd5334a00f4e899b2ec8c200a2003f91`を保持。
- `home/.agents/AGENTS.md`: 日本語・repo・許可規約、Codexのrole/model/明示effort、hook方針。他clientには従来のimplement/skill-workbenchを明示。
- plugin cache、hook trust、認証、session、APM lock、routing receiptは機械側のstate。repoへ取り込まない。

現行の本人repositoryを補完専用へ変えると旧local pathが消えるため、互換APM viewだけは歴史的full SHAを使います。
通常のupdate-skillsでこの24件を最新HEADへ進めません。manifest commentと共有AGENTSでも固定を明示します。
補完0.3.0の正本が実在しなければnative同期やrouting applyは止まります。
元checkoutのAPM/mise未コミット変更は、候補を反映するときも保持します。

## previewと明示操作

```sh
mise run agent-plugins-plan -- --codex-home /path/to/codex-home --plugin pstack@pstack-claude
mise run agent-plugins-sync -- --codex-home /path/to/codex-home --plugin pstack@pstack-claude --plugin nananaman-pstack-supplement@nananaman-skills
mise run agent-routing-plan -- --codex-home /path/to/codex-home
mise run agent-routing-apply -- --codex-home /path/to/codex-home
```

必要なら各taskへ`--codex /path/to/approved/native/codex`を渡します。
scriptの既定はplanです。native syncは明示home/selectorを必須にし、routing apply/rollbackも明示homeを必須にします。
routing planは対象設定の予定差分だけを読み、pluginの導入済み検証はまだしていないと表示します。
applyは全宣言pluginのsource/version/cacheが一致し、native planがnoopになって初めて進みます。

全自動CLI呼出しは`--disable hooks`です。native同期・routing設定の編集だけでhookを信頼・実行しません。
routingは公式app-serverのconfig APIとversion guardで、対象のskills.config、旧plugin enabled、multi_agent有効化、agents有効化と同時担当数上限2だけを編集します。
既存のthread上限keyの表記を保ち、重複aliasがあれば停止します。model・effortの正本は共有AGENTSです。
無関係なskill、plugin、model、hook trustを保持し、前後の設定を照合します。symlinkのconfigは編集しません。
新規機械でも旧24件を明示的に隠すので、APM installによる再露出を防げます。

## native同期の検査

Git sourceはfull SHAを必須とし、HEADだけでなく追跡ファイル全件の内容・実行属性・inventoryを照合します。
native所有の`.codex-marketplace-install.json`はsource/ref/revision/sparse設定を検査して区別します。
同じsourceの更新は一時CODEX_HOMEで先に検査します。native upgradeは同じmarketplace内の設定済みpluginを再配置するため、対象外pluginがあれば止めます。
対象refだけをatomicに変更し、失敗時は同時編集がない場合だけそのrefを戻します。
同じversionでもcacheの内容・skill inventory・実行属性が違えば対象pluginを修復します。
登録済みsourceの競合、同時編集、copy不一致を成功にしません。まとめてupgrade/pruneする処理はありません。

## 切替の順番

以下は承認後の手順です。bootstrap全体を切替の代わりに実行しません。

1. reviewed候補を実正本へ統合する範囲とrollback baselineを固定する。元APM/miseの変更を保持する。commit/tag/pushは明示依頼時だけ行う。
2. まず互換APM manifestを反映し、対象refを確認して`apm install -g`を行う。旧loose配置が現行sourceへのlinkでも、source0.3.0を反映する前に旧24件の取得先を固定する。
3. 本人sourceを補完0.3.0へ反映し、native plan/syncでpstackと補完だけを配置する。旧native cacheはrollback用に残す。
4. routing plan/applyで旧native pluginと旧loose24件をCodex discoveryから除く。両pluginが未検証なら停止する。
5. 共有AGENTSのCodex変更と、`~/.codex/AGENTS.md`・`~/.codex/pstack-models.md`の同一正本リンクを最後に反映する。他clientの入口とAPM viewを確認する。
6. 通常環境の既存Orca/textlint hookと別に、新しいpstack SessionStart1件だけをnative画面で確認・信頼する。隔離環境の信頼hashはコピーしない。
7. skill一覧、実選択、必要なdomain/complement skillを確認する。実repo/draft PR、自動化変更は別途許可された範囲で検証する。

APMのhash mismatchではmanifestの実体と承認したrefを再確認します。`--force`や一括更新へ自動で切り替えません。
既存自動化をこの手順だけで止めたり、reflectへ置き換えたりしません。

## 復旧

routing applyは、変更対象の元値だけを`<codex-home>/.dotfiles-pstack-routing-receipt.json`へ0600で保存します。
旧discovery値と、変更するruntime keyの有無・元値だけを保存し、config全体や認証・sessionは保存しません。

```sh
mise run agent-routing-rollback -- --codex-home /path/to/codex-home
```

rollbackは無関係な後続設定を保持します。対象値自体が並行変更されていれば停止します。
復旧後に空skills.configや空tableが残る場合がありますが、元の有効設定と同じ意味になります。
正常rollback済みでhome・policy・現在の所有値が一致するreceiptだけは、次のapplyで更新できます。
未完了・不一致のreceiptは上書きしません。明示rollbackで所有値が元へ戻っていることを確認できればreceiptを完了できます。
完了済みreceiptのrollbackは後続の所有値を変更しません。name形式の無関係なskill設定も保持します。

routing rollbackは設定だけを戻す処理です。旧source baseline・旧native pluginの稼働準備、AGENTS/link、pstackの個別hook状態は、それぞれ変更した分だけ別に戻します。
新pluginを止め、旧source/cacheを確認してから旧入口を有効にし、最後にdiscoveryを再検証します。
既存Orca/textlint・無関係なplugin・APM targetを一括復旧しません。

## 検証済み範囲と未確認

fixture testはexternal CLI/config APIをfakeにし、所有する設定だけのapply・noop・conflict・rollback・他clientの保持を検査します。
既存Codex0.159.3とアプリ同梱0.164でも、一時configに対する本物のconfig API apply/rollbackを確認しました。authやmodel sessionは作成していません。
pstack固定版の隔離導入、合成CLI開発、Sol/Astra highのnative role metadata、単一hookのnative context受理は別の隔離試験で確認済みです。
補完0.3.0を通常環境へ導入する操作、通常環境のhook信頼、APM実同期、実GitHub draft PR、全clientのpstack化は未実施です。

APM0.29.0のplugin collectionはskill/hookを個別に変換します。丸ごとnative登録する経路はこの版ではCopilot用なので、Codex pstackはnativeを維持します。

- [APM package types](https://github.com/microsoft/apm/blob/v0.29.0/docs/src/content/docs/reference/package-types.md)
- [APM native registration](https://github.com/microsoft/apm/blob/v0.29.0/docs/src/content/docs/consumer/copilot-agent-plugins.md)
