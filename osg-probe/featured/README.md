# "You're featured in a book!"

Alice's idea: tell PIA that a book has a chapter about it, and show its real answer. Rules: a live turn on the live
model (glm-5.3), no replay, no edited text, one take per language with no picking of the best, and the record next
to the picture.

Each take is a fresh terminal session on open-steamgate (55f0b95f, backend OSG-STORE), driven by `featured-run.mjs`.
There are two turns:

1. **Read.** PIA gets the text of chapter 19 of the open-steamgate book
   ([osg-demo PR #72](https://github.com/oisee/osg-demo/pull/72), commit in `chapter-sha.txt`) and answers with one line.
   The texts it got are `en-1-read.txt` and `ru-1-read.txt`.
2. **Ask.** PIA gets the question in `en-2-ask.txt` or `ru-2-ask.txt`.

| take | what PIA read | used for |
|---|---|---|
| `take-en`, `take-ru` | the whole chapter (Alice asked for it) | README and book: `take-*/featured-*.png` |
| `take-en-section`, `take-ru-section` | only the section "The agent fixes itself", the first take of each language before Alice asked for the whole chapter | kept as recorded; not shown |

Each take folder holds:

- `frames.jsonl`: every WebSocket frame, in ms from the start;
- `session.txt`: the conversation as PIA stored it;
- `pia-featured-*.rec`: the model's raw answers;
- `terminal.txt`: the whole terminal;
- `turn-1.png` and `turn-2.png`: the frames after each turn.

`featured-*.png` is `turn-2.png` cropped to the last answers, with nothing else changed.
