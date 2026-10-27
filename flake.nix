{
  description = "Haskell project template (Nix flake)";

  # tricorderはhaskell.nixでビルドされるため、キャッシュが無いとGHCからソースビルドになる。
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://tweag-tricorder.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "tweag-tricorder.cachix.org-1:PbwYPJ9gF8Wns14ai0sHK3iblqFd5YUrj0zEzGsJ/wg="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # GitHub Actionsメンテ用ツール(ghalint等)は新しいnixpkgsから取る。
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # treefmt-nixが独自にnixpkgsを取得しないよう、こちらのnixpkgsに揃える。
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    # ghcideの代わりにtricoderを使う
    # キャッシュを効かせるため、nixpkgsはfollowsさせずtricorder側のものを使う。
    tricorder.url = "github:tweag/tricorder";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      treefmt-nix,
      tricorder,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        unstablePkgs = import nixpkgs-unstable { inherit system; };
        # GHCのバージョンはここで一元管理する(treefmt.nixのormolu / hlintにも渡す)。
        ghcVersion = "ghc9122";
        hpkgs = pkgs.haskell.packages.${ghcVersion};

        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          imports = [ ./treefmt.nix ];
          _module.args = { inherit unstablePkgs ghcVersion; };
        };
        # nix flake checkはサンドボックス内でネットワークが無く、GitHub APIを叩く
        # pinactは必ず失敗するため、チェック用の評価ではpinactだけ外す。
        treefmtCheckEval = treefmt-nix.lib.evalModule pkgs {
          imports = [ ./treefmt.nix ];
          _module.args = { inherit unstablePkgs ghcVersion; };
          programs.pinact.enable = pkgs.lib.mkForce false;
        };
        # README/docs/flake等を変えてもビルドのハッシュが変わらないようにする。
        projectSrc = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.unions [
            ./myapp.cabal
            ./src
            ./app
            ./test
          ];
        };
        # 依存はmyapp.cabalのbuild-dependsだけで管理する。
        # callCabal2nixがbuild-dependsをhpkgsの同名パッケージに解決する。
        myapp = hpkgs.callCabal2nix "myapp" projectSrc { };
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        # `nix flake check`はファイルを更新せず、チェックだけを行う。(主にCI)
        # checks.*で書かれたものが走る。
        checks.build = myapp;
        checks.formatting = treefmtCheckEval.config.build.check self;
        checks.cabal-check =
          pkgs.runCommand "cabal-check"
            {
              nativeBuildInputs = [ pkgs.cabal-install ];
            }
            ''
              export HOME=$TMPDIR
              cd ${projectSrc}
              cabal check
              touch $out
            '';

        # `nix build`で実行バイナリを生成する(nix storeに動的リンクする開発用)。
        # callCabal2nixはビルド時にtest-suiteも実行する。
        packages.default = myapp;
        # musl静的バイナリ
        packages.static = pkgs.haskell.lib.justStaticExecutables (
          pkgs.pkgsStatic.haskell.packages.${ghcVersion}.callCabal2nix "myapp" projectSrc { }
        );

        # cabalはHackageではなく、nixからパッケージを取得する
        devShells.default = hpkgs.shellFor {
          packages = _: [ myapp ];
          # 依存ライブラリのドキュメント込みのローカルHoogleを使えるようにする(`hoogle server --local`)。
          withHoogle = true;
          nativeBuildInputs = [
            treefmtEval.config.build.wrapper
            pkgs.zsh
            hpkgs.haskell-language-server
            pkgs.cabal-install
            hpkgs.hlint
            tricorder.packages.${system}.tricorder
            unstablePkgs.pinact
            unstablePkgs.ghalint
          ];
        };
      }
    );
}
