# Brief for a Claude session on the lohn.cc server

Copy everything below the line into a Claude Code session on the server that hosts lohn.cc, after uploading the `wireless-display-kit/` folder there.

---

I have uploaded a folder `wireless-display-kit/` next to this prompt. It contains a README, install script, three launcher programs, two `.desktop` files and a systemd unit. Please publish it as a blog post / project page on lohn.cc.

**Goal.** A public page titled something like *"Arch Linux + KDE as a wireless display station: Miracast, AirPlay, scrcpy and a hotspot that coexists with Wi-Fi"*, plus the kit downloadable as a zip or linked to a Git repo.

**Steps.**

1. Look at how this site is built first (static generator, CMS, Markdown folder, etc.) and follow its existing conventions for posts, assets and code blocks. Do not change the site's theme or other pages.
2. Create the post from `wireless-display-kit/README.md`. Keep the structure and all code blocks exactly as written; adapt only the front matter / metadata to the site's format. Add a short intro paragraph in the site's usual voice if posts here have one. Suggested tags: arch-linux, kde, miracast, airplay, hotspot, networkmanager, pyqt6.
3. Put the kit where readers can get it:
   - preferred: a Git repository (if the site links to a Git host, create `wireless-display-kit` there and link it);
   - otherwise: zip the folder as `wireless-display-kit.zip` into the site's static/assets directory and link it from the post.
   Replace `<your-repo-url>` in the README's clone command with the real URL.
4. Also show the three main source files in the post or on a sub-page, with syntax highlighting: `bin/wireless-display` (bash), `bin/wireless-display-gui` and `bin/wifi-hotspot-gui` (python). Readers like to see the code before downloading.
5. Build the site locally if it has a build step, check the post renders (tables, code blocks, headings), then deploy the way this site is normally deployed. If deployment needs credentials or a manual step, stop and tell me what to run.
6. Report back with the public URL of the post and of the download/repo.

**Constraints.**
- Do not edit the code in the kit; if you find a bug, tell me instead.
- The README mentions the test machine's interface name `wlp0s20f3` as an example; leave it, the installer detects the real one.
- No personal data beyond what is in the README (there is none: passwords are generated at install time).
- License is MIT; add a LICENSE file to the repo if you create one.
