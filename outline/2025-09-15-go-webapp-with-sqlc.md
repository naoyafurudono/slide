---
date: 2025-09-15
---

TODO: スライド構成に落とし込んでみる。どこでどんな議論をしたいかを（その具体的な内容が決まっていなくても良いからくむ）

# スライド構成

- web appをgoで作っている
- やらないといけないのは以下の通り
  - 契約・決済の管理
  - ユーザ管理
  - 提供するインフラリソースの管理
- データはRDBに保持して、その操作をAPIで提供する
  - 決済や認証、インフラリソースの提供を実際に行うのは別のロールで、それらのapiを適切に呼び出してこのロールが管理する状態になるようにするとか、外部リソースとのやり取りの結果を自身の状態に反映して必要な調整を行うことが責務
  - 多くの操作はクライアントのapi呼び出しでトリガーされるが、時刻に依存して定期的に実行される処理もある
- プロダクトが成長するにしたがって、だんだん辛くなってくる。どんな症状があるのか（具体的にどのように困るのか）、症状の原因は何か、どんな仕組みで解消できるか

# 概要

この発表ではGoでWebアプリケーションを作る上での構成を議論する。
どんなふうにプロダクトを開発しているか、どんな辛さを感じていてどのように対処しようとしているかを議論する。

あとは企業セッションなので、企業の紹介とその中でのGoに関する取り組みと接点を紹介する
枠は15分

# 何を何のために作っているか

Web アプリケーションを作っている。ホスティングサービスを提供するために必要なWeb UIを提供する

- ホスティングリソース（サーバ、ネットワークの設定など）の操作、クライアントにインストールする設定ファイルのダウンロード
- 契約や課金の管理
- 一般的なユーザ情報の管理
  - 住所・氏名・メールアドレスなど

# 技術的な構成はどんな感じか

APIサーバとしてのバックエンド、UIとしてのフロントエンド、ユーザに提供するインフラがざっくりある
バックエンドが中心にあって、UIからの操作を受け付けたり、DBに永続化をしたり、外部サービスと連携したりする。ユーザに提供するインフラに適切なリクエストを送りもする。

「図を書く」

# どのようにプロダクトは成長していくか

- 最初はユーザ管理とリソースの簡素な提供だけをできればいい
- サブスクリプションが入り、リソース提供が複雑になったり、独自の値引きとか課金体系、決済方法の拡張が行われる
- 提供するリソース提供が増えるとか、必要な認証方法が増えることもある

# どのようにプロダクトを作るか

- APIはprotobufで定義（フロントエンドとバックエンドの間の契約をここで切る）
- データモデリングは真面目にやってRDBスキーマを真面目に定義する（データはずっと残ると思うことにして、テーブル定義はしっかりやる）
- 提供するインフラリソースもいい感じ

細かいロジックはまあいい感じに期限に間に合うように頑張る。
ある程度関心ごとで分離するけど、結局はprotobufとDBのスキーマが全て。それらと辻褄を合わせるようにする。

-> 最初はうまくいく。全てのテーブル定義とそれらの意図が開発者の頭の中に入るサイズ。sqlc がうまくハマる。みんなテーブル定義とその扱い方でプロダクトを理解しているので、どんなSQLでもスパッと呼び出せるsqlcがハマる。

例: このユーザのサーバ一覧を出す:

- userテーブルとcontractテーブルとserverテーブルをinner joinしてuser idで絞る

# 仕様はだんだん複雑になっていく

サブスクリプションが入ったあと、決済が失敗した契約は一時的に停止状態になる。停止状態の契約ではサーバの電源が落とされて利用できなくなる。

猶予期間内に支払いが完了するとサーバ操作を行えるようになり、完了しなければ強制的に解約されてサーバは削除される

DBスキーマを中心に置いてsqlcを使っている我々からしたら、SQLに一行加えればいいだけなので実装はイージー。

<!--
具体的にどのようなドツボにハマるかを説明する

サーバ一覧を取得する関数の責務がでかくなって、契約の状態でのフィルタリングが導入される
そういうクエリは簡単に書ける。
-->

# 少しずつ様子がおかしくなっていく

来月の支払い一覧と、使用しているサーバ一覧は別の概念。だけど裏では「今生きている契約の一覧」が必要で、それぞれの生きている契約について、いついくら請求されるかを計算したり、契約で提供しているサーバは何であるかを計算したりしてる。

こういう内部的に共有する「スコープ」のようなものはちょっとしたことで増えていく。
データベーススキーマを暗記していて、それらの解釈を共有しているのでなんとか毎回間違えないでクエリを書ける。
またこれらの処理は表面上異なるため、異なる関数として実装する。気がつかないうちに似たようなクエリを書いてしまっている。

RDBのテーブルは特に言語機能とかを使ってモジュール化しているわけではないので、横断する関心ごとがでかくなることもある。めちゃでかinner joinがたまにあって、その分だけ横断したテーブルの理解が必要である。
また、メソッドチェーンのようにクエリを組み合わせることはsqlcではできないので、他で使っているクエリにちょっと細工したい（例えばwhere句をちょっと変えたい）ようなときにはほとんどコピってそこだけ変えたい気持ちになる

さもなくばviewテーブルを定義すれば良さそうだが、DDLを各場所とDMLを各場所が異なるので面倒とか、そもそもモジュール化をするのって面倒なのでやられない。

# 結果としてどうなるか

- DBスキーマってモジュール化できない
- sqlc によってなんでもクエリが書ける
- sqlcで書かれたクエリは一つのGoの関数になる

トランザクションスクリプトの辛さはあるだろうか

ことにより、モジュール化が関数の単位でしかされない（統一されたデータ構造がほとんど存在しない）アプリケーションが出来上がる

メンテナンスがめちゃくちゃ大変。

- unknown unknownができる
- 影響範囲はコードをgrepしてヒットした周囲のコードを全て読むとわかる
- 切り出してスクリプト間で共有される共通処理のインターフェースは xxxID のようなものばかりで、その具体的なコンテンツを表現するデータ構造はテーブル定義にしかない
  - 結局テーブル定義を見ないとインターフェースは変わらないし、テーブル定義がちょっと変わると暗黙的にインターフェースは変わることになる

# 何が悪かったのか・どうなりたいか

典型的なトランザクションスクリプトを実装してきた。その選択の中では善処してきた。共通ロジックの関数への切り出し、テストでの正しさの担保など
それだけでは複雑さは改善されない（具体的にどんな複雑さだろうか）

プログラムの表現する対象の領域をまともに分割すること、分割した領域ごとにインターフェースを定めること、インターフェースを切った範囲の中で気合いで実装すること、インターフェースを介して適切に操作をすること。

# sqlcとの付き合い方

sqlcを使うと最強メソッドを定義できる: 全てのデータにいい感じにアクセスしていい感じの結果を返すクエリを書ける（書いちゃってる）
sqlcを用いたメソッドは再利用が難しい: テンプレートの仕組み、Railsでいうscopeの仕組みがない

https://zenn.dev/yuyu_hf/articles/6e5af8fb0af0e4#sqlクエリの条件を使い回すテンプレートの仕組みが無い

できそうなこと

- DBのビューを定義して、スコープごとに関数を定義する
  - スコープを組み合わせたいときには諦めて複数のsqlcメソッドをかく
- DBからの読み出しのスコープを小さくする
  - inner join しすぎなので、たとえN+1ができようともフィルタとかデータの収集ロジックをアプリケーションに持たせる
  - schema.sql を分割することである程度強制できる
- sqlcと離別する
- やるべきこと: 複雑さを抑えるためになんとかすること
  - 複雑さってこういうことだよね、の共通認識をチームで作る

# こういう構成はいかがだろうか

以下のようにもジュラモノリスな構成にする。それぞれのコンテキスト間のDB上での制約は表明しないことにする。
モジュール間でインターフェースを定めて、コントローラからサービスのメソッドを呼び出す。

```yaml
version: "2"
sql:
  - engine: "mysql"
    queries: "contract/query.sql"
    schema: "contract/schema.sql"
    gen:
      go:
        package: "repository"
        out: "contract/repository/"

  - engine: "mysql"
    queries: "payment/query.sql"
    schema: "payment/schema.sql"
    gen:
      go:
        package: "repository"
        out: "payment/repository/"

  - engine: "mysql"
    queries: "resource/query.sql"
    schema: "resource/schema.sql"
    gen:
      go:
        package: "repository"
        out: "resource/repository/"
```

# memo

```sql
create table products (
 id int primary key,
 name varchar,
 type varchar
)

create table contracts (
  id int primary key,
  product int,
  revenue decimal,
  dateSigned date
)

create table revenueRecognitions (
  contract int,
  amount decimal,
  recognizedOn date,
  primary key (contract, recognizedOn)
)
```

```java
class Gateway {
  public ResultSet findRecognitionsFor(long contractID, MfDate asof) throws SQLException {
      PreparedStatement stmt = db.prepareStatement(findRecognitionsStatement);
      stmt.setLong(1, contractID);
      stmt.setDate(2, asof.toSqlDate());
      ResultSet result = stmt.executeQuery();
      return result;
  }
  private static final String findRecognitionsStatement =
        "SELECT amount " +
        " FROM revenueRecognitions " +
        " WHERE contract = ? AND recognizedOn <= ?";
  private Connection db;

  public ResultSet findContract (long contractID) throws SQLException {
      PreparedStatement stmt = db.prepareStatement(findContractStatement);
      stmt.setLong(1, contractID);
      ResultSet result = stmt.executeQuery();
      return result;
  }
  private static final String findContractStatement =
    "SELECT * " +
    " FROM contracts c, products p " +
    " WHERE ID = ? AND c.product = p.ID";
}

class RecognitionService {
  public Money recognizedRevenue(long contractNumber, MfDate asOf) {
      Money result = Money.dollars(0);
      try {
        ResultSet rs = db.findRecognitionsFor(contractNumber, asOf);
        while (rs.next()) {
           result = result.add(Money.dollars(rs.getBigDecimal("amount")));
        }
        return result;
      } catch (SQLException e) {
        throw new ApplicationException (e);
      }
  }

  public void calculateRevenueRecognitions(long contractNumber) {
    try {
        ResultSet contracts = db.findContract(contractNumber);
        contracts.next();
        Money totalRevenue = Money.dollars(contracts.getBigDecimal("revenue"));
        MfDate recognitionDate = new MfDate(contracts.getDate("dateSigned"));
        String type = contracts.getString("type");
        if (type.equals("S")){
            Money[] allocation = totalRevenue.allocate(3);
            db.insertRecognition(contractNumber, allocation[0], recognitionDate);
            db.insertRecognition(contractNumber, allocation[1], recognitionDate.addDays(60));
            db.insertRecognition(contractNumber, allocation[2], recognitionDate.addDays(90));
        } else if (type.equals("W")){
            db.insertRecognition(contractNumber, totalRevenue, recognitionDate);
        } else if (type.equals("D")) {
            Money[] allocation = totalRevenue.allocate(3);
            db.insertRecognition(contractNumber, allocation[0], recognitionDate);
            db.insertRecognition(contractNumber, allocation[1], recognitionDate.addDays(30));
            db.insertRecognition(contractNumber, allocation[2], recognitionDate.addDays(60));
        }
    } catch (SQLException e) {
      throw new ApplicationException (e);
    }
  }
}
```

# 課題とかを分析する

テーブル定義をドメインの文脈ごとに切って、それを超えない範囲でクエリ定義をする処方箋が可能
sqldef + sqlcならできそう。やればいいだけ

辛いこと: sqlc のベスプラがないこと

- sqlc由来の課題
  - クエリの再利用が難しい: これは諦めるか、よっぽどたくさん使うやつはviewテーブルにしちゃう
    - 例えばフィルタ条件を実装して組み合わせることができない（Railsでいう scopeがないということ）
  - テーブル定義が一箇所にまとまりがち: ドメインの文脈ごとに切ればいい。ここから先はjoinしないでアプリケーションレイヤでよしなに通信してもらって、DBでこれ以上繋げても辛いだけ、な領域を見出す（マイクロサービスを切る時もきっとそういう分け方をするのでしょう）
    - マイクロサービスを切るのに比べて、DBの制約をつけられることと、やろうと思えば同一のDBトランザクションにクエリ実行を入れることができる
  - コードを読んでいてデータ操作メソッドが何をしているか分かりにくい問題
    - クエリが別のファイルに書かれていて、そのクエリを呼び出すコードを書くときに、そのクエリが実際に何をしているか分かりにくい: クエリ名しか手掛かりがない
      - オプションがある。コメントにクエリ定義をコピーできる。とても便利。導入した当初は敗北した気持ちになったけど、まあそんなものだろうと思うようになった。抽象化したくなったらGoのレイヤで重ねればいい。コメントに書けないと定義ジャンプできる範囲にクエリの実装がないことになるので読みづらい。
  - ビジネスロジックの実装があらゆるところに
