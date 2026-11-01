# Installing the CouchSubs TV app on an LG TV

Until the CouchSubs TV app is available in the LG Content Store, it is installed in developer mode.
You only do this once.

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

Install Node.js from [nodejs.org](https://nodejs.org) (or `brew install node` on a Mac). Then, in Terminal
(PowerShell on Windows):

```bash
npm install -g @webos-tools/cli
ares-setup-device --add tv --info "{'host':'TV_IP','port':'9922','username':'prisoner'}"
ares-novacom --device tv --getkey
```

The last command asks for the Passphrase. If you get "Failed to get ssh private key", the Key Server has
closed: turn it on again and run the command right away. If the timing doesn't work, on a Mac you can download the key
directly and enter the Passphrase afterwards:

```bash
curl -o ~/.ssh/tv_webos http://TV_IP:9991/webos_rsa && chmod 600 ~/.ssh/tv_webos
ares-setup-device --modify tv --info "{'privatekey':'tv_webos','passphrase':'PASSPHRASE'}"
```

## 3. Install the TV app

Download `com.couchsubs.tv_…_all.ipk` from [Releases](https://github.com/yorulmazsinan/couchsubs/releases/latest)
and run, in the folder you downloaded it to:

```bash
ares-install -d tv com.couchsubs.tv_0.6.0_all.ipk
```

(From source: `ares-package tv-webos -o dist`, then `ares-install -d tv dist/com.couchsubs.tv_*.ipk`.)

Then open CouchSubs on your computer; the setup assistant finds the TV and launches the app for you.
