# wkwk

Wkwk - Perlで作られた簡易コードジェネラーター

## install

```
chmod 755 wkwk.pl
sudo cp wkwk.pl /usr/local/bin/wkwk
wkwk --version
```

## 設定方法 

プロジェクトのルートディレクトリに .wkwk というディレクトリを作成し、そこに設定ファイルを作成していく。

もし、グローバルの設定ファイルを作成したい場合は、~/.wkwk の様にディレクトリを作成し、そこに設定ファイルを作成することで、
グローバルに使えるようになる。
Wkwkは、再帰的にディレクトリをチェックしていき、.wkwkディレクトリが存在するかを確認する。

## ファイルの作成方法

設定ファイルは以下の様に記述していく。

- dist 出力するpath。pwdを基準にpathを書く。
- src 出力する元になるファイル。
- content 出力する文字列。

もし、srcとcontentが両方記述されている場合は、srcの方が優先される。

また、generateディレクティブの他に、appendディレクティブも用意されている。
generateはファイルを上書きするのに対し、appendはファイルに追加する。

```
generate:
    dist: 
        director.php
    end_dist:

    src:
        generate/sample.php
    end_src:

    content: 
<?php
class @@class@@
{
    public function __construct()
    {
        $this->sample = $sample;
        parent::__construct();
    }

    public function index()
    {

    }
}

    end_content:

end_generate:
```


例えば、上記の設定ファイルを.wkwk/admin というファイル名で作成した場合は、
wkwk admin とコマンドを実行すると、 カレントディレクトリに director.phpが作成される。

また、generate appendは複数用意することができる。