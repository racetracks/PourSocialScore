# Rules for using scratch

## Rules the author has set
1. **Use the scratch repo for hosting** test zips, handover packs, documentation and SavedVariables.
2. **Easily human-readable folders**: plain words, dates as `YYYY-MM-DD-hh-mm`, versions in file names.
3. **Version everything hosted**: builds by addon version, packs by `<date>-vN`, saves by the version that wrote them.
4. **A `SavedVariables/` folder must exist.**
5. **A `releases/` folder must exist.**
6. **A `docs/` folder must exist.**
7. **A `summary/` folder must exist.**
8. **A `latest/` folder must exist.**
9. **Test zips go in `releases/`**: every build made before the release workflow is zipped. The newest zip goes in `latest/`, and at the same time a versioned, dated copy goes in the root of `releases/`.
10. **Docs go in `docs/`**: the newest markdown in `docs/latest/<project-or-feature>/`; a project or feature release also gets a history folder `docs/<project-or-feature>/`; every docs release is zipped in the root of `docs/`. Organise files into folders where possible.
11. **A description README** in each top folder the author may come back to "when confused".
12. **Bugfix builds are hosted** like any build: the next build number, zipped, on scratch, with a link.
13. **Real saves live here (this repo is the project files), never in an addon repo:** `SavedVariables/<version>/`.
14. **Always reply with links**, never only a path.
15. **No pull requests on scratch (2026-10-09):** commit and push straight to `main`, even when a session is given a working branch for this repo; a delivery waiting on a PR is not hosted. If a PR is requested for scratch work, it is opened in the primary (addon) repository `racetracks/PourSocialScore` instead (the author, 2026-10-10).

## Rules to add
<!-- The author adds further scratch rules here. -->
