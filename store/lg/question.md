# Seller Lounge 1:1 Q&A: gönderimden önce sorulacak soru

**Subject:** Pre-submission question: showing an HDMI input behind a subtitle overlay

Hello,

Before submitting our web app, we would like to confirm whether its approach is acceptable for the LG
Content Store.

**The app:** CouchSubs (`com.couchsubs.tv`) is a free, open-source accessibility app. It shows a game console
connected over HDMI full screen and draws translated subtitle text on top of it. The text comes from our
companion desktop app (macOS and Windows) on the same local network, over HTTP Server-Sent Events. The TV app
collects no data.

**What the app uses today:**

1. To show the HDMI input, a `<video>` element with `<source type="service/webos-external" src="ext://hdmi:N">`,
   with the HTML page transparent on top of it. We could not find this in the public documentation.
2. To find which HDMI port the console uses, `luna://com.webos.service.eim/getAllInputStatus` through
   `PalmServiceBridge`. This call is optional: when it fails, the user picks the port with the number keys.
   The service is not in the ACG Developer Guide table, so we do not know which group to declare in
   `requiredACG`.
3. The companion desktop app launches the TV app with launch parameters over the TV's local network control
   connection, after the user accepts the pairing prompt on the TV.

**Our questions:**

1. Is an app that uses `ext://hdmi` as described eligible for the LG Content Store?
2. If not, is there a supported API or a partner program (for example webOS Partner Zone) that allows an app
   to show an HDMI input with an overlay?
3. Can the app use `getAllInputStatus`, and if so, which ACG group should it declare? If not, we will remove
   the call.
4. Can the app be distributed in Türkiye?

Reviewers do not need a console: the app has a demo mode that plays sample subtitles from the first screen.

Thank you,
Enmera
