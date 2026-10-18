# Linked copies of the startup files

Generated, never edited: each file here is a startup file (one that `CLAUDE.md` loads at session start, or `CLAUDE.md` itself) with every key and path turned back into a link, for reading on GitHub ([`DEC-00340`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/00_Decisions.md#dec-00340)). The sources cite keys and paths bare, resolved through the reference index (scratch [`REGISTRY.md`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/16_Registries/REGISTRY.md)), so each session loads fewer tokens.

| Copy | Source |
| --- | --- |
| [CLAUDE.linked.md](CLAUDE.linked.md) | [`CLAUDE.md`](../../CLAUDE.md) |
| [11_PREFERENCES.linked.md](11_PREFERENCES.linked.md) | [`docs/pss/11_PREFERENCES.md`](../pss/11_PREFERENCES.md) |
| [06_STATUS_AND_NEXT.linked.md](06_STATUS_AND_NEXT.linked.md) | [`docs/pss/06_STATUS_AND_NEXT.md`](../pss/06_STATUS_AND_NEXT.md) |
| [15_ROUTES.linked.md](15_ROUTES.linked.md) | [`docs/pss/15_ROUTES.md`](../pss/15_ROUTES.md) (on demand; moved from `CLAUDE.md`) |
| [16_INTERFACE.linked.md](16_INTERFACE.linked.md) | [`docs/pss/16_INTERFACE.md`](../pss/16_INTERFACE.md) (on demand; moved from `CLAUDE.md`) |

Regenerate after any change to a source, from a scratch checkout beside this repo:

```sh
cd ../Pour-Social-Score_Scratch
for f in CLAUDE.md docs/pss/11_PREFERENCES.md docs/pss/06_STATUS_AND_NEXT.md docs/pss/15_ROUTES.md docs/pss/16_INTERFACE.md; do
	python3 documents/reference-framework/08_Operations/registry-tool/link_keys.py --render ../PourSocialScore/$f ../PourSocialScore/docs/linked/$(basename $f .md).linked.md --addon ../PourSocialScore
done
python3 documents/reference-framework/08_Operations/registry-tool/link_keys.py --startup ../PourSocialScore/CLAUDE.md ../PourSocialScore/docs/pss/11_PREFERENCES.md ../PourSocialScore/docs/pss/06_STATUS_AND_NEXT.md ../PourSocialScore/docs/pss/15_ROUTES.md ../PourSocialScore/docs/pss/16_INTERFACE.md
```
