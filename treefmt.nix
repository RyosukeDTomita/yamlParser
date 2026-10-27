{
  pkgs,
  unstablePkgs,
  ghcVersion,
  ...
}:
{
  projectRootFile = "flake.nix";

  # nixファイルの整形。nixfmt-treeと同じRFC 166スタイルに揃える。
  programs.nixfmt.enable = true;
  programs.nixfmt.package = pkgs.nixfmt-rfc-style;

  # mdformat本体はthematic breakを変換するため、`---`のまま出力する
  # mdformat-simple-breaksプラグインを使う。programs.mdformatはpackage
  # 上書きを尊重しないためsettings.formatterで直接指定する。
  # .claude/配下のSKILL.mdはYAML frontmatterを持ち、mdformatが壊すので除外する。
  settings.formatter.mdformat = {
    command = "${pkgs.mdformat.withPlugins (ps: with ps; [ ps.mdformat-simple-breaks ])}/bin/mdformat";
    includes = [ "*.md" ];
    excludes = [ ".claude/**" ];
  };

  # flake.nixのghcVersionと同じGHCのバージョンに合わせる。
  programs.ormolu.enable = true;
  programs.ormolu.package = pkgs.haskell.packages.${ghcVersion}.ormolu;

  # treefmt controls mode/idempotence itself; pass only parser options.
  settings.formatter.ormolu.options = [
    "--ghc-opt"
    "-XImportQualifiedPost"
  ];

  # ormoluの整形後の内容を検査するようpriorityで後に回す。
  programs.hlint.enable = true;
  programs.hlint.package = pkgs.haskell.packages.${ghcVersion}.hlint;
  settings.formatter.hlint.priority = 1;

  # GitHub Actionsのusesをコミットハッシュに固定する。
  # --updateはバージョンを勝手に上げるため無効にし、未固定のusesの固定だけ行う。
  programs.pinact.enable = true;
  programs.pinact.package = unstablePkgs.pinact;
  programs.pinact.update = false;

  # pinactが固定した後の内容を検査するようpriorityで後に回す。
  settings.formatter.ghalint = {
    priority = 1;
    command = "${pkgs.writeShellScript "ghalint-run" ''exec ${unstablePkgs.ghalint}/bin/ghalint run''}";
    includes = [
      ".github/workflows/*.yml"
      ".github/workflows/*.yaml"
    ];
  };
}
