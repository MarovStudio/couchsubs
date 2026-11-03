# Installing the CouchSubs TV app on an LG TV

Until the CouchSubs TV app is available in the LG Content Store, it is installed in developer mode. You
turn developer mode on; CouchSubs on your Mac or Windows PC installs the TV app and keeps it up to date.

## 1. Developer mode on the TV

1. Create a free LG developer account at [webostv.developer.lge.com](https://webostv.developer.lge.com)
   (**Sign In › Create Account**).
2. Install and open the **Developer Mode** app from the LG Content Store on the TV.
3. Sign in with your email address and password.
4. Turn on **Dev Mode Status**; the TV restarts.
5. Open the Developer Mode app again, turn on **Key Server** and **leave the app open on screen** (it turns
   off when you switch away). The TV's IP address and a **Passphrase** are shown.

Developer mode expires after a while; extend it from the Developer Mode app.

## 2. On your computer

1. Open CouchSubs. In the TV step, pick your TV, press **Connect** and accept the prompt on the TV.
2. When a passphrase is requested, open the Developer Mode app on the TV, turn on **Key Server** and keep
   the app on screen.
3. Type the **Passphrase** shown on the TV and press **Install on the TV**.

The passphrase is asked once. CouchSubs installs later versions by itself when you start translating. After
setup the same card is also in **Settings**. If you turn developer mode off and on again, the TV creates a new
key and the passphrase is asked once more.

## Manual install

If the automatic install does not work, install [Node.js](https://nodejs.org) and run this in Terminal (PowerShell on Windows):

```bash
npm install -g @webos-tools/cli
ares-setup-device --add tv --info "{'host':'TV_IP_ADDRESS','port':'9922','username':'prisoner'}"
ares-novacom --device tv --getkey
ares-install -d tv com.couchsubs.tv_0.6.1_all.ipk
```

Download the package from the [releases](https://github.com/yorulmazsinan/couchsubs/releases/latest) page.
If you get "Failed to get ssh private key", Key Server has closed: turn it on again and rerun the command right away.
