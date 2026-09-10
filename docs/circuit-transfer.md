# 緑回路による数量指定荷役（1.0.5）

## 配線

- **本体の赤線**：従来の在庫出力用。読み取り設定や配線をMODは変更しません。
- **専用入力口の緑線**：外部回路が計算した「現在の残量」の入力用。
- 入力口の選択範囲は、初期状態では本体の左端（横長）／上端（縦長）にあります。1台につき1個、自動生成されます。補助ランプの画像は点灯・消灯とも透明で、反転後も表示されません。選択と配線は従来どおり可能です。
- 手に何も持たず本体か入力口にカーソルを合わせ、標準の「水平反転」「垂直反転」のどちらかを押すと、横長は左端⇔右端、縦長は上端⇔下端へ切り替わります。どちらの操作でも1回押すごとに反対端へ移動します。
- 選んだ端はセーブ・再読み込み・設定更新・入力口修復後も保持します。既存セーブは左端／上端が初期値です。blueprintや新規cloneには継承しません。blueprintやアイテムを手に持っている間は入力口を切り替えません。
- 本体の緑線と入力口の赤線は直接荷役の判定に使用しません。

入力口はlamp型の補助entityで、インベントリも信号出力も持ちません。手動で設置・採掘するアイテムはなく、衝突・照明・電力消費・独自設定GUIもありません。要求回路を本体や別のチェストの在庫回路につながないでください。1 request networkにつき1 TrainContainerを推奨します。

## 動作と保存

入力口の緑線未接続なら、従来の500個／10tick、手動5スロット、Whitelist/Blacklist、retryが有効です。接続中は正のitem＋quality信号をそのサイクルの最大数量として一括荷役します。ゼロ・負値・非item信号は対象外。接続中に正の要求がなければ停止します。

`circuit_set_filters=false`は要求信号と手動filterのAND、trueは要求信号をdynamic whitelistとして使用します。設定は消去せず、OFFへ戻せば手動filterが復帰します。Loading mode OFFでも設定と入力口を保持します。

所有関係は`storage.train_request_inputs.owners[unit_number]`に本体・入力口参照と破棄通知の登録番号を保存します。設定はschema 4の`{mode, slots, circuit_set_filters}`を維持します。要求quotaは保存せず、全stack／貨車／同一本体の複数列車groupでサイクル内だけ共有し、実移送量を減算します。移送は既存の安全な`transfer_stack`経路を使用します。

既存セーブには更新時に入力口を追加します。既存入力口があれば再作成せず配線を保持します。本体の古い緑線は自動で移動しないため、要求線は入力口へ付け替えてください。未接続の間は通常荷役になります。入力口自体をblueprintやcopy/pasteへ保存しません。新設・cloneされた本体には未配線の入力口が付きます。split／採掘／破壊時には入力口も削除されます。

GUIは入力口の緑線を基準に有効／無効を表示します。開いている画面だけ15tickごと、active transferは従来の10tickごとに再確認します。全worldを毎tick走査しません。status lampとCybersyn2 shimの意味・荷役条件は変更していません。

## 数量の保証範囲

自己在庫差し引き処理は完全に廃止しました。Factorio 2.0.77実機で本体の在庫を同tick内に増減しても、入力口の要求700は700のままであることを検証しています。本体赤線からの在庫出力も維持されています。

回路そのものの伝播遅延は残ります。正確さは**その処理サイクルで取得した信号値を超えない**という保証です。外部回路が次の10tick処理までに残量を更新する必要があります。定数+2000を出し続けると、毎サイクル最大2000個を許可します。一回限りの累積目標ではありません。

## テスト

```text
lua tests/train_request_inputs.lua
lua tests/train_filters.lua
lua tests/train_circuit_transfer.lua
lua tests/train_transfer_gui.lua
lua tests/train_status_lamps.lua
lua tests/train_loading_graphics.lua
```

```powershell
./tests/run_circuit_engine.ps1 -Factorio 'D:/Games/steam/steamapps/common/Factorio/bin/x64/factorio.exe'
```

本体テストは`.verify-circuit/`にコピーしたMODと専用セーブを使用します。テストフックや毎tickの測定処理はそのコピーにだけ追加されます。通常セーブを使いません。

実機検証：12000個のbulk Load、Unload、要求ゼロ、入力口の信号分離、同tickの本体在庫増減、赤線の在庫出力、body-green／input-redの無視、実貨車filter/bar、入力口の再構築と配線保持、blueprint除外、入力口修復、本体破壊後の削除。荷役テストの停車状態は代替値であり、駅到着からの一連の走行試験ではありません。

Luaテストでは品質とmetadata、複数貨車・複数列車group、断続供給、設定変更・migration・cleanup、1:1 ownership、clone／teleport／orphan cleanup、既存event handlerの保持、shim作成／削除、ランプ、グラフィックも検証します。

実際の利用時は、駅で停止させた貨車とTrainContainerを隣接させ、定数回路→入力口greenへ鉄板+700を送ってLoad／Unloadを確認してください。次に外部回路で「目標−貨車在庫」を計算し、断続供給・品質別要求・複数貨車で確認してください。GUIの入力口選択と拡大率、マルチプレイでの操作、実際の駅到着からの一連の運用は追加の目視／運用確認対象です。

## 設計根拠：旧方式の時刻差の実測

Factorio 2.0.77で、`LuaCircuitNetwork.signals`、`LuaEntity.get_signals(circuit_green)`、`LuaCircuitNetwork.get_signal(signal)`、`LuaEntity.get_signal(signal, circuit_green)`を同じコールバック内で比較しました。4つとも同じ値を返し、在庫の同tick内の変更には追従せず、次tickに更新されました。毎回network参照とsignals配列を新規取得しており、Lua側で古い配列を使い回した結果ではありません。

専用の定数回路を緑線でTrainContainerに接続し、外部要求は鉄板+700に固定。直接荷役を実行しない別のコンテナで、スクリプトから在庫を変更しました。

| tick / 操作 | 現在在庫 | network.signals | entity.get_signals | network.get_signal | entity.get_signal | 各値－現在在庫 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 54 / 変更前 | 3000 | 3700 | 3700 | 3700 | 3700 | 700 |
| 54 / 100個追加直後 | 3100 | 3700 | 3700 | 3700 | 3700 | 600 |
| 55 / 次tick | 3100 | 3800 | 3800 | 3800 | 3800 | 700 |
| 56 / 200個削除直後 | 2900 | 3800 | 3800 | 3800 | 3800 | 900 |
| 57 / 次tick | 2900 | 3600 | 3600 | 3600 | 3600 | 700 |

またtick 60で定数回路の要求を700から900へ変更しても、同tickは4 APIすべて3600、tick 61ではすべて3800でした。在庫は2900のままです。

**結論：この2.0.77実機検証では、取得APIの置き換えだけで現在在庫との時刻差を解消できません。** 検証は同tick内のLua在庫変更について確定したもので、あらゆる設備の更新順序を網羅する試験ではありません。この検証を根拠として、本体greenを読む方式を廃止し、専用入力口を採用しました。

例：前tick在庫3000＋外部要求700＝回路3700。その後100個を追加すると、現在在庫3100との差は600となり、外部要求700と一致しません。在庫が減った場合は逆に過大な要求になる可能性があります。今回確認したAPIにはチェスト自身の前tick出力を直接取得する手段がありません。

専用入力口ではこの差し引きを行わず、ネットワークから取得した正値を直接quotaにします。

根拠：[LuaCircuitNetwork.signals](https://lua-api.factorio.com/latest/classes/LuaCircuitNetwork.html#signals)、[LuaContainerControlBehavior](https://lua-api.factorio.com/latest/classes/LuaContainerControlBehavior.html)。最新ドキュメントは2.1系ですが、実装に使うAPIはローカル2.0.77のAPI定義とも照合しています。

