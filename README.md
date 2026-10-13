<p align="center"><img src="docs/icon.png" width="96" alt="Study Timer icon"></p>

<h1 align="center">Study Timer</h1>

<p align="center">A macOS menu bar timer that logs study sessions to Notion.</p>

<p align="center"><img src="docs/screenshot.png" width="320" alt="A running countdown"></p>

## Setup

You need macOS 27 and Swift 6.4.

1. Make two Notion databases:
   - **Sessions** with one title, one date, and one relation to Cards.
   - **Cards** with a title. An optional `Status` select puts `Doing` cards first.
2. Turn on [Developer Mode](https://www.notion.com/help/turn-on-developer-mode-to-use-developer-tools-in-notion)
   and create a [personal access token](https://developers.notion.com/guides/get-started/personal-access-tokens).
3. In Sessions, open ••• → Developer → Copy Data source ID.
4. Build and launch:

   ```sh
   ./build.sh
   defaults write dev.local.StudyTimer dataSourceID <data-source-id>
   open "$HOME/Applications/Study Timer.app"
   ```

5. Press ⌃⌥S and paste the token.

`swift test` runs the tests. It needs Command Line Tools in `/Library/Developer/CommandLineTools`.
