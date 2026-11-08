# ADHD の人が読める「カジリが作ったもの」にする — 調査と対策

2026-11-08。カジリが作って届けるもの（一覧・チェックリスト・調べもの・下書き）を、ADHD の人が読める長さと形にするために調べたことと、それを元に直したこと。

## きっかけ

iPhone Duo の実機で「住所変更の手続き一覧（期限の目安つき）」を開いたら、こう出ていた。「こういう長文は絶対に ADHD には読めない」と言われた。

```
【引っ越し前にやる】
・郵便の転居届
郵便局の窓口かネットで出す。旧住所あての郵便が1年間新住所に届く（要確認）
1週間前までに出すと安心（要確認）
・電気・ガス・水道
止める手続きと開ける手続きをする。目安は1週間前まで（要確認）
ガスを開けるときは本人の立会いが要る（要確認）
……
```

読めない理由は5つあった。

1. 項目（転居届）と説明（窓口かネットで…）が同じ太さ・同じ大きさで、どこが要点か見分けられない
2. 「（要確認）」が見えている範囲だけで7回くり返される。中身ではないのに、毎行で目が止まる
3. 「市区町村が変わるときだけ」のような分かれ目を、項目ごとに自分に当てはめて読む必要がある
4. 「引っ越し日：（ここに日付）」のような、紙に書きこむための空欄がアプリでは書けない
5. 「・」で始まっていたので、チェックもできない

## 調べて分かったこと

論文は、ほとんどが要旨と二次資料（レビュー・解説）で読んだ。原文で数字を確かめていないものは、そう書いてある。子どもや学習教材を対象にした研究が多く、大人の手続きの一覧にそのまま当てはまるとは限らない。

| 分かっていること | 出典 | カジリでどうするか |
|---|---|---|
| ADHD の子どもは、文章の**要点（中心の情報）**を拾って思い出すところで、定型発達の子との差がいちばん大きい（centrality deficit）。説明できる差のうち、作業記憶がいちばん効いていた | Miller et al. 2013, *J Abnorm Child Psychol* 41(3) | 要点を読み手に探させない。**要点だけを書き手（カジリ）が選んで書く** |
| ADHD の子どもの作業記憶は、定型発達の子より大きく低い（音韻 g≈0.69、視空間 g≈0.74） | Kasper, Alderson & Hudec 2012, *Clin Psychol Rev* 32 | 一度に覚えておく量を減らす |
| 人が一度に頭に置いておけるのは、4まとまりくらい | Cowan 2001, *Behav Brain Sci* 24(1) | 1つの段は5つまで。開いておく段は1つだけ |
| ADHD の青年は持続的注意も読解も低く、二つは相関する | Stern & Shalev 2013, *Res Dev Disabil* 34 | 長く読ませるほど落ちる。**読む量そのものを減らす** |
| 不注意の傾向が強い人ほど、読んでいるあいだに考えがそれ（マインドワンダリング）、読解が下がる | Jonkman et al. 2017, *PLoS ONE*／Franklin et al.（Tracking Distraction） | 同上 |
| 面白いけれど要らない情報（誘惑的詳細）を入れると、学習が下がる。58研究のメタ分析で g = −0.33 | Rey 2012, *Educ Res Rev* 7(3)／Sundararajan & Adesope 2020, *Educ Psychol Rev*（数字は解説記事から） | 「旧住所あての郵便が1年間新住所に届く」のような**理由・効果・豆知識は消す**（Mayer の一貫性原理） |
| 大事なところを目で分かるようにする（シグナリング）は、覚えていることに強く効き、使うことにも中くらいに効く。103研究のメタ分析 | Schneider et al. 2018, *Educ Res Rev* 23（解説資料から） | 項目は太字、説明は小さく灰色、次にやる1つに色を付ける |
| 自分のペースで進める小分け（セグメンティング）は、覚える・使う両方に小〜中の効果 | Rey et al. 2019, *Educ Psychol Rev* 31 | 段ごとに開いて進む |
| 段階的開示: 最初は主な情報だけを見せ、二次的なものは後ろに置くと、覚えやすく間違いにくい | Nielsen Norman Group | 説明の2行目からは「くわしく」にたたむ |
| Web の文章は、平均で2〜3割しか読まれない | Nielsen 2008 "How Little Do Users Read?"（解説から） | **各行の頭に要点を置く**。読まれるのは頭だけと考える |
| 認知や学習に障害のある人向けには、短い文・短いかたまり・はっきりした見出し、主な作業は1〜3つに絞る | W3C, *Making Content Usable for People with Cognitive and Learning Disabilities* | 同上 |
| やさしい日本語の書き方は、最初の手順が「情報を整理する」「文をわかりやすくする」 | 出入国在留管理庁・文化庁『在留支援のためのやさしい日本語ガイドライン』2020 | 書く前に要る情報を選ぶ |
| ADHD の支援は、知識を足すより、**それをやる場所**に手がかりを置く（point of performance） | Barkley（解説から） | 期限・場所は、その項目のすぐ下に書く |
| 「もし X なら Y する」の計画（実行意図）で、ADHD の子の抑えが定型発達の子と同じくらいまで良くなった | Gawrilow & Gollwitzer 2008, *Cogn Ther Res* 32 | 項目は「何をする」で終える。「次はこれ」を付ける |
| 効かないもの: 単語の前半を太字にする Bionic Reading は、読む速さを上げない | Snell 2024, *Acta Psychologica* 247 | 見た目の小細工ではなく、**中身を減らす** |

### 結論

- **いちばん効くのは、書く量を減らすこと。** ADHD の人は要点を拾うところでつまずくので、拾う作業をこちらで済ませる
- 残すのは「何をする（動詞）・いつまでに・どこで・何を持って」だけ。理由・仕組み・効果・言い換えは、正しくても消す
- 消せない情報は、**目で分かる重みの差**（太字の項目と小さな説明）と、**たたむ**（くわしく・閉じた段）で後ろに回す
- 同じ注意をくり返さない。確かめきれないことは、最後の1行にまとめる

## 削ってよいもの・残すもの

| 残す | 削る | まとめる |
|---|---|---|
| やること（動詞で終える1行） | 理由・仕組み・効果・豆知識・言い換え | 確かめきれない日数や期限 → 最後の「※ 」1行 |
| いつまでに・どこで・何を持って（その項目に要るものだけ） | 行ごとの「（要確認）」 | 人によって要る・要らない → 見出しで分ける（【市区町村が変わるときだけ】） |
| 書きこむ欄（メモ：） | 紙で使うための説明（□ を ■ に変える） | |

## やったこと

### 1. カジリへの指示（`functions/src/prompts.ts` の `workSystemPrompt`）

- 「相棒は長い文を読めない。読むのは各行の頭だけだと思って書く。正しいことでも、相棒のやることが変わらない文は書かない」を最初に置いた
- 一覧は「□ 」で1行1つ、動詞で終える、25字まで。下に足すのは、いつまでに・どこで・何を持って、のどれかを1行だけ（30字まで）
- 1つの段は5つまで、全部で12までを目安にする。段の中に小見出しを作らない
- 分かれ目は見出しで分ける。メモで分かるなら、要らない方は書かない
- 「要確認」を行ごとに付けず、最後に「※ 」の1行にまとめる
- 調べものは、答えを1文で書いてから要点を3つまで
- 送る文は、用件を先に書いて1文を短くする

### 2. 画面（`WorkDocument` と `WorkChecklistView`）

- 項目は太字1行。説明は小さく灰色で1行だけ出し、2行目からは「くわしく（あと N 行）」にたたむ。済んだ項目は説明を消す
- まだチェックしていない最初の項目に「次はこれ」を付け、琥珀色で囲む
- チェックリストは**今やっている段だけ開く**。済んだ段と先の段は「見出し 0/3 ›」の1行。押せば開く
- 行ごとの「（要確認）」は外して、いちばん下に注意を1行だけ出す
- 「引っ越し日：（ここに日付）」は書く欄、「同じ市区町村か：（はい／いいえ）」は押して選ぶ欄にする
- 前の指示で届いていた長い文（「・」の並び）にも同じ読み方をする。「・」の項目はチェックしない（メールの下書きの「・」を □ に変えて送ってしまわないため）
- メールの下書きのような地の文は、送る形のまま見せる（行の間を少し広げた）

### 3. 測ったこと（`evals/work/`）

直した指示で、本番と同じ呼び方（Opus 5.5・Web 検索つき）で作らせた。数字は [evals/work/out/summary.md](../evals/work/out/summary.md)。

| | 直す前（画面から書き起こした見本。全文ではない） | 直した後（住所変更） |
|---|---|---|
| 項目の数 | 8 | 10 |
| 1項目あたりの文字数 | 約57字 | 約35字 |
| 「要確認」 | 7回 | 0回（最後に ※ の1行） |
| いちばん長い項目の行 | 説明を入れて3行 | 16字 |
| 分かれ目 | 項目ごとのかっこ書き | 【市区町村が変わるとき】【同じ市区町村のとき】の見出し |

立会いのチェックリスト・粗大ごみの出し方・歯医者へのメールでも、□ の行は25字以内、「要確認」は0回だった。

## まだ確かめていないこと

- ADHD の人に、直す前と後を読んでもらって比べてはいない。上の数字は長さと形だけ
- お題は4つで、1回ずつしか流していない
- 調べものの「答えを1文で」は、手順を聞くお題（粗大ごみ）ではチェックリストになったので、答えを聞くお題ではまだ見ていない

## 出典

- Miller, A. C., Keenan, J. M., Betjemann, R. S., Willcutt, E. G., Pennington, B. F., & Olson, R. K. (2013). Reading comprehension in children with ADHD: Cognitive underpinnings of the centrality deficit. *J Abnorm Child Psychol*, 41(3), 473–483. https://pmc.ncbi.nlm.nih.gov/articles/PMC3561476
- Kasper, L. J., Alderson, R. M., & Hudec, K. L. (2012). Moderators of working memory deficits in children with ADHD: A meta-analytic review. *Clin Psychol Rev*, 32, 605–617. https://www.pubmed.gov/22917740/
- Cowan, N. (2001). The magical number 4 in short-term memory. *Behav Brain Sci*, 24(1), 87–114. https://pubmed.ncbi.nlm.nih.gov/11515286/
- Stern, P., & Shalev, L. (2013). The role of sustained attention and display medium in reading comprehension among adolescents with ADHD and without it. *Res Dev Disabil*, 34, 431–439. https://www.scilit.net/publications/4ab09b7b9c4cdb7580586e6ab0d214cf
- Jonkman, L. M., Markus, C. R., Franklin, M. S., & van Dalfsen, J. H. (2017). Mind wandering during attention performance: Effects of ADHD-inattention symptomatology… *PLoS ONE*. https://doaj.org/article/9131fa4c5b4546f1832d096da3bff95b
- Franklin, M. S., Mrazek, M. D., et al. Tracking Distraction: The Relationship Between Mind-Wandering, Meta-Awareness, and ADHD Symptomatology. https://labs.psych.ucsb.edu/schooler/jonathan/publications/651
- Rey, G. D. (2012). A review of research and a meta-analysis of the seductive detail effect. *Educ Res Rev*, 7(3). 解説: https://inspire.acu.edu.au/articles/seductive-details
- Sundararajan, N., & Adesope, O. (2020). Keep it coherent: A meta-analysis of the seductive details effect. *Educ Psychol Rev*. 解説: https://news.wsu.edu/press-release/2020/03/19/seductive-details-inhibit-learning
- Schneider, S., Beege, M., Nebel, S., & Rey, G. D. (2018). A meta-analysis of how signaling affects learning with media. *Educ Res Rev*, 23, 1–24. 解説: https://www.qic-wd.org/sites/default/files/Umbrella%20Summary%20-%20Signaling%20in%20Training%20111021.pdf
- Rey, G. D., Beege, M., Nebel, S., Wirzberger, M., Schmitt, T. H., & Schneider, S. (2019). A meta-analysis of the segmenting effect. *Educ Psychol Rev*, 31, 389–419. https://www.doi.org/10.1007/S10648-018-9456-4
- Nielsen Norman Group. Progressive Disclosure. https://www.nngroup.com/videos/progressive-disclosure/
- Nielsen, J. (2008). How Little Do Users Read? 解説: https://service-manual.ons.gov.uk/content/writing-for-users/how-people-read-online
- W3C (2021). Making Content Usable for People with Cognitive and Learning Disabilities. https://www.w3.org/TR/coga-usable
- 出入国在留管理庁・文化庁 (2020). 在留支援のためのやさしい日本語ガイドライン. https://www.moj.go.jp/isa/content/930006072.pdf
- Barkley, R. A. の point of performance について（解説）: https://www.simplypsychology.org/can-you-have-adhd-and-be-organized.html
- Gawrilow, C., & Gollwitzer, P. M. (2008). Implementation intentions facilitate response inhibition in children with ADHD. *Cogn Ther Res*, 32, 261–280. https://www.socmot.uni-konstanz.de/publications/implementation-intentions-facilitate-response-inhibition-adhd-children
- Snell, J. (2024). No, Bionic Reading does not work. *Acta Psychologica*, 247. https://pubmed.ncbi.nlm.nih.gov/38723450/
