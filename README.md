# yamlParser

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## ABOUT

Springのapplication.yaml用のparser
yamlの葉に対するチェックは行わずに、事前定義されたrulesにないキー名を検知する。

---

## HOW TO USE

### Initial Set Up

```shell
nix develop
# direnvを使う場合
direnv allow
```

### run locally

```shell
runghc -isrc -iapp app/Main.hs
```

```shell
cabal run yaml-parser
```

---

## For Developer

### test

```shell
runghc -isrc test/Spec.hs
# コメントに書いた`>>>`の例(doctest)を実行する
cabal repl --with-compiler=doctest yamlParser
# nix上でビルドしてtest-suiteを実行する(CIと同じ)
nix flake check
```

### build

```shell
# nix storeに動的リンクしたバイナリ
nix build
# musl静的バイナリは初回はソースビルドになり遅いが、Nixユーザ以外に配れるバイナリを作れる。
nix build .#static
```

### formatter

- treefmt
  - ormolu
  - hlint(lintのみ。指摘があると失敗する。ポイントフリーを避けるため`.hlint.yaml`で`Eta reduce`を無効化)
  - nixfmt
  - mdformat
  - ghalint
  - pinact

> [!NOTE]
> pinactはGitHub APIを使うため、ネットワークの無い`nix flake check`ではpinactを除外している。

```shell
nix fmt
# ビルド・テスト・整形漏れ・hlint・cabal checkのチェック(CIでも実行)
nix flake check
```

### tricorder

ファイル変更を監視し、lib/exe/testを継続的にビルド・テストする(devShellに同梱)。設定は`.tricorder.yaml`。

```shell
tricorder ui
# 非対話で確認する場合
tricorder start
tricorder status
tricorder test suites
```
