Dart Multi Touch Demo
=====================

Setup device
http://developer.android.com/sdk/index.html
https://developers.google.com/chrome-developer-tools/docs/remote-debugging

Create new tunnel 
```
adb forward tcp:9222 localabstract:chrome_devtools_remote
```

Open the web interface 

```
http://localhost:9222/
```

Launch Dartium version first then let adb open on tablet. This should trigger a dart2js call automatically.  

```
adb shell am start -a android.intent.action.VIEW -d $url
```



This demo was based off the work of Tim Branyen, Mike Taylr, Paul Irish & Boris Smus canvas multi touch sample.