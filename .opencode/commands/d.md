---
description: 保留中のAIDJ directiveを実行してackする
---

現在のroleに対応する`tui_id`で保留中directiveをconsumeし、FIFO順にすべて実行する。
OSCメッセージを正常にqueueした後だけtokenをackする。directiveがなければ、何も変更せず
`## <tui_id> idle - no directive`の1行だけを返す。
