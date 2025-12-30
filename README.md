# LinkShell

LinkStationの簡易的なシェル接続ツール。
LinkStationのssh環境をセットアップする用途で使用する想定です。
（初代ポケモンでのバイナリエディタを作るときに使うプログラムマシンのようなイメージ）

> [!WARNING]
> 本ツールの使用により発生したいかなる損害についても、作者は一切の責任を負いません。自己責任でご利用ください。

## 動作環境

- Ruby 3.4
- Java Runtime
- LS-WVL/R1 本体
- [Buffalo LinkStation Series Updater Ver1.75](https://www.buffalo.jp/support/download/detail/?dl_contents_id=60849)

## 使い方

### 元に戻す方法

1. Updaterのlinkstation_version.ini、linkstation_version.txtのバージョン情報を書き換える

この２つのファイルの`2025/12/08`という日付を未来に進め、`VERSION`を`1.75-0.02`のように変えてあげます。

2. Updaterを実行する

なお、以下のようなバージョンが変わっていない旨の警告が出ますが、特に問題はないです：

```
LinkStationのファームウェアが書き換わったことを確認できませんでした
kernel [2020/12/08 15:03:07]  （LinkStationのファームウェア）
kernel [2020/12/09 15:03:07]  （アップデート後の正しいファームウェア）

ファームウェアのアップデートに失敗した可能性があります
```

### LinkShellの使い方

```
❯ : ruby linkshell.rb -h
Usage: linkshell.rb [options]
    -t, --target TARGET              Your LinkStation's IP address
    -p, --password PASSWORD          Your LinkStation's admin password
    -i, --interval SECONDS           Interval between commands
    -T, --tries N                    Number of tries for each command
        --stop                       Stop the LinkShell if already running
    -v, --verbose                    Run verbosely
```

この後、`/etc/sshd_config`を書き換えたり、`/root/.ssh/authorized_keys`に公開鍵を追加したりして、ssh環境を整えてください。

> [!WARNING]
> このツールはかなり脆弱です（認証なしでシェルにアクセスできるようになります）。
> sshdをセットアップしたら、直ちにこのツールを停止してください。

## 仕組み

LS-WVL/R1にはbusyboxが入っています。
busyboxで動く簡易的な遠隔シェルをacp-commander経由でインストールし、それに接続しています。

## ライセンス

MIT Licenseで公開しています。
