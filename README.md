<p align="center">
  <img src="docs/images/app-icon.png" width="128" alt="Little Plant application icon: a 3D Monstera on a raised silver tile">
</p>

# Little Plant

Grow a little plant inside your laptop, listen to lo-fi music, and take a moment to chill.

Add a little green to your MacBook’s menu bar. Put a lo-fi CD on the player, settle into your cozy room, and focus on your work while your Monstera grows beside you.

A native macOS app with rough, nostalgic 3D graphics and a handheld-console-inspired interface. Available in English and Korean.

## Install and launch

Requires **macOS 13 or later**.

### Download the app

> **Audio update:** Do not redistribute the old v0.1.0 installer. The music library has been updated; use a rebuilt v0.1.2 or later release containing Pillowcase Moon and Starlight Through the Blinds.

[**Replacement installer release status →**](https://github.com/luminous037/Little-Digital-Plant-in-my-Laptop/releases)

The old direct-download button is temporarily disabled because the v0.1.0 installer contains removed third-party recordings. Download a rebuilt v0.1.2 or later installer only after it has been published. No source code or build tools are needed for DMG installation.

> **Release status:** v0.1.0 must not be redistributed. A replacement DMG is being prepared. Publishing a new version does not remove the old release asset; the old DMG must be deleted separately.

1. **Download:** open the release page above and choose **Little-Plant.dmg** from a replacement release (v0.1.2 or later). If your browser asks, choose **Save File**. The file is normally saved in **Downloads**.
2. **Open:** open `Little-Plant.dmg` from your browser’s downloads list or from Finder → Downloads.
3. **Install:** in the disk image window, drag **Little Plant.app** onto the **Applications** folder shortcut. Wait for copying to finish.
4. **Eject:** eject **Little Plant** from Finder’s sidebar. The installed app stays in Applications.
5. **Launch:** open Finder → Applications → **Little Plant**. Look for the leaf icon in the menu bar; there is no Dock icon.
6. **Open your room:** click the leaf icon. Click it again, or click outside the room, to hide it.

If you have an older copy running, quit it from the menu-bar icon before replacing it in Applications.

The app runs in the menu bar and does not appear in the Dock. Right-click the leaf icon and choose **Quit Little Plant** to exit. You can also use **Settings → Quit**.

Current development builds are ad-hoc signed and are not notarized by Apple, so macOS may require you to approve the app in **System Settings → Privacy & Security** on first launch.

### Build from source

Install **Xcode Command Line Tools** with Swift 5.9 or later. Download or clone the project, then double-click **Run Little Plant.command** in Finder. It builds and opens the app. The first build may take a few minutes.

Or use Terminal:

```sh
./scripts/build-app.sh
open "dist/Little Plant.app"
```

### Package a DMG

```sh
./scripts/build-dmg.sh
```

This creates `dist/Little-Plant.dmg` and its SHA-256 checksum. The installer contains the app and a shortcut to Applications for drag-and-drop installation. By default it targets your build Mac's architecture. To package a universal app for both Apple silicon and Intel Macs:

```sh
LITTLE_PLANT_UNIVERSAL=1 ./scripts/build-dmg.sh
```

The GitHub Actions packaging workflow builds a universal DMG. Run it manually to download the installer artifact, or push a version tag such as `v0.1.0` to create a **draft release** with the installer attached. Review and publish the draft to make the direct download button work. Keep the release asset named exactly `Little-Plant.dmg`, since the README download URL uses that filename. Alternatively, create a GitHub Release manually, upload `dist/Little-Plant.dmg` and `dist/Little-Plant.dmg.sha256`, and publish it. A draft release is not publicly downloadable. After publishing the first release, remove the release-status notice above.

Apple Developer ID signing and notarization are not configured in this workflow.

On first launch, macOS may ask to use your location for local weather. If you decline, the room uses virtual weather. No API key is required.

## Your little room

The three bottom buttons open **Care**, **Weather**, and **Camera**. Click the plant, window, books, and CD albums directly to interact with them. Hovering over an interactive object gives a small visual hint.

Use the gear button in the upper-right corner to change the language, adjust music and effects volume, toggle rain sounds, or quit.

The images below are actual captures of the running app in English, using isolated demonstration plants and photos. Your first plant starts with **two fully grown leaves**.

## Care for your plant

**Your plant grows into different shapes depending on how you care for it.** Water, airflow, light, and fertilizer affect new leaf growth. The number of leaves and their sizes change as your Monstera grows, pauses, and regrows after pruning.

<table>
  <tr>
    <td align="center"><img src="docs/images/growth-starter.png" width="140" alt="Actual plant model with two mature leaves"><br><sub>Two mature leaves</sub></td>
    <td align="center"><img src="docs/images/growth-sprout.png" width="140" alt="Actual plant model with two mature leaves and a small new third leaf"><br><sub>A small new leaf</sub></td>
    <td align="center"><img src="docs/images/growth-growing.png" width="140" alt="Actual plant model with four leaves of different sizes"><br><sub>Four leaves, mixed sizes</sub></td>
    <td align="center"><img src="docs/images/growth-full.png" width="140" alt="Actual plant model with six fully grown leaves"><br><sub>Six fully grown leaves</sub></td>
  </tr>
</table>

These examples use the app’s actual 3D plant and growth rules, rather than separate illustrations.

<img src="docs/images/care.png" width="420" alt="Plant care bubble showing Water, Fertilize, soil moisture, fertilizer concentration, and the plant name">

- **Open the care bubble:** click the plant or the bottom leaf button. It shows soil moisture, fertilizer concentration, and a short description of how your plant is doing.
- **Water:** wait until the soil is nearly dry. Choose **Water**, then click and drag the metal watering can to spray. Water must reach the soil to count. Release to stop, and press **Esc** or × to put the can away.
- **Ventilate:** click the window to open or close it. Open it after watering, then close it before a long, cold night.
- **Fertilize:** choose **Fertilize** to drop four pellets into the pot. Fertilizer helps new leaves grow faster; your plant does not need it to stay green. Avoid keeping the concentration at 100% for too long.
- **Trim:** when leaves turn yellow or dry out, use the scissors button and click the damaged leaf. Yellow leaves do not turn green again.
- **Grow:** keep water, daylight, and ventilation balanced. New leaves grow one at a time, up to six leaves. At the current 1.5× plant-time rate, a new leaf takes about 32 real hours of good growing conditions without fertilizer; fertilizer can speed this up.
- **Name your plant:** click the pencil beside its name in the care bubble.

The green **Plant Stories** book on the shelf contains a short care guide. These are simplified game rules, rather than horticultural advice.

### When leaves wilt

**Too little water, too much water, or prolonged exposure to cold night air can make leaves turn yellow and eventually wilt.** Damage starts with individual leaves, so keep an eye on the soil moisture and avoid leaving the window open through long, cold nights.

<img src="docs/images/withered.png" width="360" alt="Actual app screenshot showing all six leaves dark, dried, and bending downward, with the scissors button for pruning damaged leaves">

Yellow or dried leaves will not turn green again. Click the **scissors button**, then click the damaged leaf to trim it. After pruning, restore a good balance of water, daylight, and airflow: **a new leaf can sprout in the empty spot and grow in its place**. New leaves grow one at a time and pause when growing conditions are no longer suitable.

### Plant time and sleep

All time-dependent plant processes run at **1.5× real time**, including soil drying, fertilizer consumption, airflow, root stress, growth, yellowing exposure, and withering. For example, one real hour now advances the plant by 1.5 hours; a 24-hour damage threshold is reached after about 16 real hours of continuous exposure. The open-window night threshold is about 32 real night hours.

The plant keeps changing while its menu-bar window is hidden. If your Mac sleeps while Little Plant is running, the full elapsed time is applied when it wakes, using the last known weather and window position. Fresh local weather is requested afterwards when needed; historical weather during sleep is not retrieved. Quitting the app still pauses plant time until the next launch.

## Play a lo-fi CD

<img src="docs/images/music.png" width="420" alt="The my cozy room CD album brought forward from the shelf">

1. Click a CD album on the shelf to bring its cover forward.
2. Click the album again to take out the CD.
3. Click the CD to send it gently into the wall-mounted player.
4. **Click the black pull cord** to start the music. The cord pulls down and the disc begins spinning. You do not need to drag it.
5. Click the cord again to pause. While stopped, click the disc in the player to return it to its album.

<img src="docs/images/player.png" width="420" alt="A CD inserted into the wall-mounted player with its black pull cord below">

Choose from **my cozy room**, **Pillowcase Moon**, and **Starlight Through the Blinds**. Return the current CD before loading another. Music and effects have separate volume controls in Settings.

## Set the weather and time of day

<img src="docs/images/weather.png" width="480" alt="The running room and its Weather menu with Simulation, Location, Day, Night, Clear, and Rain controls">

Click the bottom weather button. Select **Simulation**, then choose **Day** or **Night**, and **Clear** or **Rain** independently. All four combinations are available. This changes the room’s environment; the clock still shows your Mac’s current local time, and plant time advances at 1.5× real time.

Select **My location** to use local weather instead. If location or weather is unavailable, the app falls back to virtual weather.

<img src="docs/images/night.png" width="420" alt="The room at night with blue moonlight entering through the window">

Night brings blue moonlight into the room. Rain adds moving pixel rain and ambient rain sounds. Open the window to hear louder rain; turn rain sounds off in Settings whenever you prefer.

## Take and revisit photos

<img src="docs/images/camera.png" width="420" alt="A freshly captured Polaroid floating in front of the room, with capture date and plant name">

1. Click the bottom **camera button**. A flash captures the room at that moment and a Polaroid floats forward.
2. The picture leaves out the temperature, clock, and settings button. Its lower-right corner records the date and your plant’s name at the time of capture.
3. **Click the floating card to save it.** It flies into the white **Plant Records** book beside Plant Stories on the shelf.

<img src="docs/images/album.png" width="420" alt="Plant Records open to two pages, each holding a Polaroid with gray share and pale red delete buttons">

- Click the white book, then its cover, to open the album. It is always on the shelf, even before your first photo.
- Use the page arrows to browse. Each page holds one card. Going back from the first spread closes the cover.
- Click a card to bring it forward and enlarge it. Click it again, or click outside it, to return to the album.
- Click the **gray share icon** below a card to copy the photo card to the clipboard. A brief confirmation appears; paste it into another app to share it.
- Click the **pale red trash icon** to delete a photo. Confirm **Yes** or **No** in the dialog, which includes the saved capture date.

Saved photos remain available after restarting the app. They are stored locally in `~/Library/Application Support/LittlePlant/PlantRecords/`.

## Project files

- `Sources/LittlePlant/` — native macOS interface, SceneKit room, audio, camera, and album.
- `Sources/PlantCore/` — plant growth and care rules.
- `Sources/LittlePlant/Resources/Fonts/` — bundled Nintendo DS BIOS and Galmuri14 fonts.
- `Sources/LittlePlant/Resources/Music/` — lo-fi CD tracks.
- `Sources/LittlePlant/Resources/Sounds/` — rain, page turns, and player effects.
- `Sources/LittlePlant/Resources/AppIcon.icns` — application icon built from the project’s 3D plant.
- `docs/images/` — the application icon preview and actual app screenshots used in this guide.
- `scripts/build-app.sh` — builds and packages `dist/Little Plant.app`.
- `scripts/build-dmg.sh` — creates the drag-and-drop DMG installer.
- `.github/workflows/release.yml` — builds a universal DMG and prepares draft releases.

Local weather is provided by [Open-Meteo](https://open-meteo.com/).

## Bundled music

The current library contains **my cozy room**, **Pillowcase Moon**, and **Starlight Through the Blinds**. The latter two recordings were supplied for this project and are packaged in `Sources/LittlePlant/Resources/Music/`. The previous procedurally synthesized recordings and their generator have been removed from the current project.
