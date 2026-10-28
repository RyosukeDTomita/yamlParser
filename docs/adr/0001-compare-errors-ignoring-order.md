# 0001: 複数エラーのテストは順序を無視して比較する

- Status: Accepted
- Date: 2026-10-28

## Context

`validate`は`[Err]`を返す。エラーが複数あるとき、その並び順はYAMLの`Object`(aesonの`KeyMap`)をたどる順で決まる。

`KeyMap`はYAMLファイルの記述順を保持しない。順序は実装に依存する。

- aesonのビルドフラグ`ordered-keymap`が有効(デフォルト)なら`Data.Map`で、キーのアルファベット順になる
- 無効なら`HashMap`で、ハッシュ値の順になる。`hashable`のバージョンが変わると順序も変わる

同じビルドの中では順序は変わらないが、nixpkgsの更新などでaesonの設定や依存のバージョンが変わると変わりうる。

テストで確かめたいのは「どのエラーが出るか」であって、「どの順で出るか」ではない。

## Decision

エラーが2件以上になるテストは、hspecの`shouldMatchList`で比較する。

```haskell
errPaths (validate [] schema doc) `shouldMatchList` [["foo"], ["server", "bar"]]
```

エラーが0件か1件のテストは、順序の問題が起きないため`shouldBe`のままにする。

### 採用しなかった案

- `shouldBe`で順序まで比較する: aesonの内部実装に依存し、ライブラリ更新でテストが壊れうる
- 結果の`last`だけを比較する: エラーの過不足(検出漏れ、重複、余計なエラー)を見逃す。エラーが0件のときは`last []`が例外になる

## Consequences

- aesonの`KeyMap`の実装や依存のバージョンが変わっても、テストは影響を受けない
- エラーの件数と中身は引き続き検査される
- `validate`の出力順序そのものは保証されない。順序を保証したくなったら、`validate`側でソートしてから`shouldBe`で比較する
