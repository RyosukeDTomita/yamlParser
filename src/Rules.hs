{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wunused-imports #-}

module Rules (rules) where

import Parser (closed)
import Schema (Schema (..))

-- ユーザ独自定義のルールを書く。
-- Spring Bootのapplication.yamlのうち、よく使うキーだけを許可するルール例
rules :: Schema
rules =
  closed
    [ ("spring", spring),
      ("server", server),
      ("management", management),
      ("logging", logging)
    ]

spring :: Schema
spring =
  closed
    [ ("application", closed [("name", Open)]),
      ( "profiles",
        closed
          [ ("active", Open),
            ("include", Open)
          ]
      ),
      ( "config",
        closed
          [ ("activate", closed [("on-profile", Open)]),
            ("import", Open)
          ]
      ),
      ( "datasource",
        closed
          [ ("url", Open),
            ("username", Open),
            ("password", Open),
            ("driver-class-name", Open),
            ("hikari", Open) -- プール設定は項目が多いので検査しない
          ]
      ),
      ( "jpa",
        closed
          [ ("show-sql", Open),
            ("open-in-view", Open),
            ( "hibernate",
              closed
                [("ddl-auto", Open)]
            ),
            ("properties", Open)
          ]
      )
    ]

server :: Schema
server =
  closed
    [ ("port", Open),
      ("shutdown", Open),
      ("servlet", closed [("context-path", Open)])
    ]

management :: Schema
management =
  closed
    [ ( "endpoints",
        closed
          [("web", closed [("exposure", closed [("include", Open)])])]
      ),
      ("endpoint", MapOf Open) -- endpoint名(health, info, ...)ごとの設定
    ]

-- logging.level.<パッケージ名>: <レベル>
logging :: Schema
logging =
  closed
    [ ("level", MapOf Open),
      ("file", closed [("name", Open), ("path", Open)])
    ]
