# CLAUDE.md

## ライブラリの追加

依存パッケージはnixpkgsから取得する。Hackageからは取得しない。

1. `.cabal`の該当stanza(`library` / `executable` / `test-suite`)の`build-depends`にパッケージ名を足す。
1. direnv使用時は`cd`し直す(`.envrc`が`*.cabal`を`watch_file`している)。不使用なら`nix develop`し直す。
1. `cabal build`する。

- `flake.nix`のdevShellは`hpkgs.shellFor`で`.cabal`から依存を読むため、`flake.nix`を編集する必要はない。
- `cabal update`や`cabal install`は使わない。`cabal.project`の`active-repositories: :none`でHackageを参照しない設定のため、効果がない。
- `unknown package: <name>`が出たら、nixの評価が失敗して古いdevShellのままになっていることを疑う。`nix develop -c cabal build all`で直接確認する。

## よくある落とし穴

- flakeはgit管理外のファイルを見ない。新規の`.cabal`や`src/*.hs`は`git add -N <file>`で追跡対象にしてから`nix develop`する。
- `.cabal`をリネームしたら`flake.nix`の`projectSrc`の`./<name>.cabal`と`callCabal2nix "<name>"`も合わせて変える。古い名前のままだとnixの評価が失敗する。
- `.ghci`でデフォルトimportするライブラリは`/sync-ghci`スキルで同期する。
