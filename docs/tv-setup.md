# Installing the CouchSubs TV app

The TV apps are not in the stores yet, so you turn on developer mode on your TV. It is free and does not harm the TV.

| TV | Status | Guide |
|---|---|---|
| **LG** (webOS 4+) | Tested on a real TV. CouchSubs installs the TV app itself | [LG](#lg-tv) |
| **Samsung** (Tizen) | Not tested on a real TV yet. Needs your own Samsung certificate | [Samsung](#samsung-tv) |
| **Android TV / Google TV** (Vestel, Arçelik, Beko, Grundig, Philips and others) | Not tested on a real TV yet | [Android TV](#android-tv--google-tv) |
| **Linux models of Vestel, Arçelik, Beko and Grundig, Philips Saphi and Titan OS** | Not supported: we found no way to install apps on them | |

The computer and the TV must be on the same home network.

## LG TV

1. Create a free account at [webostv.developer.lge.com](https://webostv.developer.lge.com) (**SIGN IN › Create Account**).
2. On the TV, install **Developer Mode** from the LG Content Store and sign in with that account.
3. Turn on **Dev Mode Status**. The TV restarts.
4. Open CouchSubs on your computer. In the TV step, pick your TV, press **Connect** and accept the prompt on the TV.
5. Open the Developer Mode app again, turn on **Key Server** and keep the app on screen.
6. Type the 6-character, case-sensitive **Passphrase** shown at the bottom left of the TV into CouchSubs and press **Install on the TV**.

CouchSubs installs later versions by itself. **Remain Session** in the Developer Mode app shows the time left (1000 hours
at most). Press **EXTEND** before it runs out: when it expires, developer mode turns off and the TV app is removed.

## Samsung TV

Samsung requires apps to be signed for each TV, so CouchSubs cannot install it for you. Not tested on a real TV yet.

1. In the TV's **Apps** screen enter `12345`, turn **Developer mode** on, enter your computer's IP address and restart the TV.
2. Install [Tizen Studio](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/installing-tv-sdk.html)
   with the Samsung Certificate Extension. Add the TV in **Device Manager** and create a **Samsung** certificate profile in
   **Certificate Manager**, adding the TV's DUID to the distributor certificate.
3. Unzip `CouchSubs-samsung-kaynak.zip` from [Releases](https://github.com/yorulmazsinan/couchsubs/releases), then run
   `tizen package -t wgt -s PROFILE -- FOLDER` and `tizen install -n FOLDER/CouchSubs.wgt -t TV_NAME`.
4. In the TV step of CouchSubs, pick your Samsung TV and press **Connect**. If the app does not open, open it on the TV; it finds your computer by itself.

## Android TV / Google TV

Not tested on a real TV yet. Some TVs may not give the HDMI picture to other apps: subtitles appear but the picture stays
black. Please report your TV model in [Issues](https://github.com/yorulmazsinan/couchsubs/issues).

1. In **Settings › Device Preferences › About** press OK on **Build** 7 times, then allow your file manager under **Unknown sources**.
2. Copy `CouchSubs-androidtv.apk` from [Releases](https://github.com/yorulmazsinan/couchsubs/releases) to a USB stick and install it with a file manager on the TV. To update, uninstall the old app first: the package has a temporary signature for now.
3. In the TV step of CouchSubs, select **Android TV / Google TV**, then open CouchSubs on the TV. It finds your computer by itself.
4. If there is no picture, press OK for the panel and pick the HDMI input with left and right.
