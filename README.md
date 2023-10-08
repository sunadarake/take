# take

take - Perlで作られた簡易コードジェネラーター

## install

- Linux, Mac

```
curl -fsSL https://raw.githubusercontent.com/sunadarake/take/main/take > take
chmod +x take
sudo cp take.pl /usr/local/bin/take
take --version
```

- Windows

```
curl -fsSL https://raw.githubusercontent.com/sunadarake/take/main/take.bat > take.bat
```

PATHが通っているディレクトリに`take.bat`を移動する。

## 設定方法 

プロジェクトのルートディレクトリに .take というディレクトリを作成し、そこに設定ファイルを作成していく。

もし、グローバルの設定ファイルを作成したい場合は、~/.take の様にディレクトリを作成し、そこに設定ファイルを作成することで、
グローバルに使えるようになる。
takeは、再帰的にディレクトリをチェックしていき、.takeディレクトリが存在するかを確認する。

## 使い方

まずは、`.take`ディレクトリに`src/sample.php`を用意する。
その後、`admin`ファイルを作成し、以下の様に記述する。

```
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"
```

上記の設定後、`take admin`とコマンドを入力することで、`src/sample.php`のファイルを元に
`bar.php`が作成される。

また、アクションは複数用意することができる。

```
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"

- name: copy other file
  copy:
    src: "src/other.php"
    dist: "oreore.php"
```

## 変数、コマンドライン

テンプレートファイルではPerlの式や変数を使うことができる。

例えば、`src/sample.php`を下記の様に書いておく。

```
<?php
    class <@= $class @>
    {
@ for $meth (@$methods) {
    public function <@= $meth @>
@ }
    }
```

そして`sample`ファイルを以下の様に定義する。


```
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"
```

`take sample class=Sample methods=index,show,create`とコマンドを実行することで、
takeはコマンドライン引数を元に変数展開をし、コードを生成する。


## アクション例

アクションは`copy`の他に様々なものがある。


### copy

指定したファイルをコピーできる。

```
- name: copy single file
  copy:
    src: "src/sample.php"
    dist: "bar.php"
```

また、以下の様にloop処理で複数のファイルを指定できる。

```
- name: copy multiples
  copy:
    src: "src/sample.php"
    dist: "{{ item }}.php"
    with_items:
      - foo
      - bar
```

### insert

特定のファイルの特定の場所にコードを挿入できる。

```
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "# hello comment"
    before: "class Sample"
```

上記の様に設定する事で`src/sample.php`の`class Sample`という文字が含まれる行の前に
`# hello comment`を挿入できる。

```
- name: copy single file
  insert:
    dist: "src/sample.php"
    content: "# hello comment"
    after: "class Sample"
```

逆に指定するコードを後に挿入したい場合は、`after`オプションを使えば良い。

### perl

perlのコードを書くことができる。

```
- name: Execute perl
  perl: 'say "hello"'
```

複数指定することもできる。

```
- name: Execute perl
  perl:
    - 'say "hello"'
    - 'say "take easy"'
```

### command

外部コマンドを呼び出すことができる。

```
- name: copy single file
  command: 'echo "hello"'
```

これも複数指定が可能。


```
- name: copy single file
  command:
    - 'echo "hello"'
    - 'echo "take easy"'
```

## テンプレートの作成方法

takeではテンプレートエンジンにMicroTemplateを採用している。

https://github.com/kazuho/p5-text-microtemplate

書き方としては以下の様に書ける。

```
<?php
    class <@= plural($class) @>
    {
@ for $meth (@$methods) {
    public function <@= $meth @>
@ }
    }
```

`<@= $sample @>`で変数展開ができ、行の先頭に`@`を記述することで
Perlのコードを書くことができる。

また、変数展開時にはPerlのコードと同様に関数を使うことができる。

例えば、以下の様な例がある。

- uc
- ucfirst
- lc
- lcfirst

他にもtake独自の関数を用意している

- plural 単数形を複数形に変換する。(song → songs)
- camel2snakse キャメルケースをスネークケースに変換 (myVar → my_var)
- snake2camel スネークをキャメルに変換 (my_var → myVar)
