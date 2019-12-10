# qshowコマンド

`pbsnodes -aSj` や `qstat -ft` の出力をいい感じに表示するコマンドです．


## 最新のビルド済みバイナリのダウンロード

```sh
$ wget https://github.com/k3kaimu/cluster-tools/releases/latest/download/qshow
$ chmod +x qshow
```


## 表示例

`````
$ qshow
vnode   state     njobs  ncpus f/t  mem f/t      gpu       users
------  --------  -----  ---------  -----------  ---  ----------
xsnd00      free      5       3/28   50gb/192gb  2/2  c222222*21,   aa000* 4
xsnd01      free      6       2/28   30gb/192gb  2/2  c222222*21, b111111* 1,   aa000* 4
xsnd02      free      5      14/28  124gb/192gb  2/2  b111111* 1, d333333*10,   aa000* 3
xsnd03      free      2      26/28  160gb/192gb  2/2  b111111* 2
xsnd04      free      2      26/28  160gb/192gb  2/2  b111111* 2
xsnd05  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
xsnd06  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
xsnd07  job-busy      8       0/28   26gb/192gb  2/2  c222222*21, b111111* 1,   aa000* 6
xsnd08  job-busy      8       0/28   26gb/192gb  2/2  c222222*21, b111111* 1,   aa000* 6
xsnd09  job-busy      1       0/28    0gb/192gb  2/2  d333333*28
xsnd10  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
xsnd11  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
xsnd12  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
xsnd13  job-busy      8       0/28   38gb/192gb  2/2  c222222*21,   aa000* 7
------  --------  -----  ---------  -----------  ---  ----------

Username    tJob  tCPU  tMem      rJob  rCPU  rMem    
----------  ----  ----  --------  ----  ----  --------
     aa000    65    65   264.0GB    65    65   264.0GB
   b111111     2     8   128.0GB     2     8   128.0GB
   c222222    22   462  2772.0GB    10   210  1260.0GB
   d333333     4    94   616.0GB     2    38   232.0GB
----------  ----  ----  --------  ----  ----  --------

Job ID      Username    S  tCPU  tMem      rMem      vMem      CPU(%)  CPU Time    Walltime  
----------  ----------  -  ----  --------  --------  --------  ------  ----------  ----------
     66615       aa000  R     1     8.0GB     0.1GB     0.7GB       4    00:00:36   167:26:58
     77357     b111111  R     4    64.0GB     0.1GB     2.2GB      75    00:00:09    25:41:00
     77359     b111111  R     4    64.0GB     0.1GB     2.7GB      75    00:00:10    25:18:10
     77421     d333333  R    28   192.0GB     0.1GB     1.7GB      98    00:00:11    19:51:55
     77425     d333333  R    10    40.0GB     0.1GB     2.5GB      81    00:00:12    19:14:55
     77608     d333333  Q    28   192.0GB         ?         ?       0  ----:--:--  ----:--:--
     77609     d333333  Q    28   192.0GB         ?         ?       0  ----:--:--  ----:--:--
  77628[2]     c222222  R    21   126.0GB     2.2GB     9.0GB    2040    08:05:01    00:24:22
  77628[3]     c222222  R    21   126.0GB     2.2GB     9.0GB    2017    08:02:37    00:24:17
  77628[4]     c222222  R    21   126.0GB     2.1GB     9.0GB    2045    08:09:49    00:24:22
  77629[0]     c222222  Q    21   126.0GB         ?         ?       0  ----:--:--  ----:--:--
  77629[1]     c222222  Q    21   126.0GB         ?         ?       0  ----:--:--  ----:--:--
  77629[2]     c222222  Q    21   126.0GB         ?         ?       0  ----:--:--  ----:--:--
  77629[3]     c222222  Q    21   126.0GB         ?         ?       0  ----:--:--  ----:--:--
  77629[4]     c222222  Q    21   126.0GB         ?         ?       0  ----:--:--  ----:--:--
----------  ----------  -  ----  --------  --------  --------  ------  ----------  ----------
`````

## オプション

* `-h`, `--help`

ヘルプを表示します．

* `-n`, `--node`

ノードの情報を表示します．

* `-u`, `--user`

ユーザーの情報を表示します．

* `-j`, `--job`

ジョブの情報を表示します．

* `-m`, `--mine`

自身のジョブのみ表示します．

* `-c`, `--color`

カラー表示を有効にします．

* `--noheader`

`vnode   state     njobs  ncpus f/t  mem f/t      gpu       users`や，その次の行のハイフンの表示を無くします．
フォーマット指定と組み合わせることで，qshowの結果を他のシェルスクリプトやプログラムで処理する際の利便性が向上すると思われます．

* `--nodefmt`

ノードの情報を表示する際のフォーマットを指定します．
デフォルトでは`--nodefmt='%name:6s  %state:8s  %njobs:5s  %cpu:9s  %mem:11s  %gpu:3s  %users:-(%10s, %)'`と等価です．
詳しくは[フォーマット指定の書式](#フォーマット指定の書式)を参照してください．

* `--userfmt`

ユーザーの情報を表示する際のフォーマットを指定します．
デフォルトでは`--userfmt='%user:10s  %tjob:4s  %tcpu:4s  %tmem:8s  %rjob:4s  %rcpu:4s  %rmem:8s'`と等価です．
詳しくは[フォーマット指定の書式](#フォーマット指定の書式)を参照してください．

* `--jobfmt`

ジョブの情報を表示する際のフォーマットを指定します．
デフォルトでは`--jobfmt='%id:10s  %user:10s  %queue:6s  %name:20s  %S:1s  %tcpu:4s  %tmem:8s  %rmem:8s  %vmem:8s  %cpup:6s  %cput:10s  %walltime:10s'`と等価です．
詳しくは[フォーマット指定の書式](#フォーマット指定の書式)を参照してください．


### フォーマット指定の書式

qshowではオプションの`--nodefmt`，`--userfmt`，`--jobfmt`を与えることで表示する情報のフォーマットを変えることができます．
フォーマット指定文字列はC言語のように`%`から始まる記法になっています．
より詳細には，`%{column-name}:{column-width}{fmt-spec}`となっており，`{column-name}`はカラム名，`{column-width}`はカラムの文字数，`{fmt-spec}`は`s`などのフォーマット指定子です．
`{column-width}`が指定されていない場合は表示する文字列の長さは無制限であると解釈します．

たとえば，次の例では各ノードのノード名（6文字まで）と割り当てられているジョブの数（4文字まで）を表示します．
また，二つのカラムの間には四つの半角スペースを挿入しています．

```sh
$ qshow -n --nodefmt='%name:6s    %njobs:4s'
vnode     njob
------    ----
xsnd00       4
xsnd01       3
xsnd02       4
xsnd03       1
xsnd04       1
xsnd05       8
xsnd06       8
xsnd07       8
xsnd08       7
xsnd09       1
xsnd10       7
xsnd11       7
xsnd12       7
xsnd13       7
------    ----
```

他のプログラムでqshowの出力を処理したい場合，`--noheader`オプションを有効にしてカンマ区切りやスペース区切りで出力すると便利かもしれません．

```sh
$ qshow  --noheader -n --nodefmt='%name:s,%njobs:s'
xsnd00,0
xsnd01,1
xsnd02,1
xsnd03,1
xsnd04,1
xsnd05,7
xsnd06,7
xsnd07,7
xsnd08,7
xsnd09,1
xsnd10,4
xsnd11,0
xsnd12,0
xsnd13,0
```


## ビルド

1. 以下のページを参考にしてD言語のコンパイラをインストールします

    [@outlandkarasu D言語環境構築 2019年版 - Qiita](https://qiita.com/outlandkarasu@github/items/faa555d5c1d1d19a8fa4)

2. このリポジトリをクローンしてビルドすると`qshow`というバイナリができあがります

```sh
$ git clone https://github.com/k3kaimu/cluster-tools
$ cd cluster-tools
$ dub build --single qshow.d
$ ls -al
README.md  qshow  qshow.d
```