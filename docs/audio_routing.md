# Audio Routing

AIDJはCUE Send Trackと各Trackの`#Send`を自動作成するが、物理出力名はaudio interfaceと
driverごとに異なるため自動選択しない。

## Recommended Single-Interface Setup

1. 4出力以上のaudio interfaceをRenoiseのASIO deviceに選ぶ。
2. Master TrackをOutput 1/2へrouteする。
3. `cue` Send TrackをOutput 3/4へrouteする。
4. Output 1/2をPA/recorder、Output 3/4をheadphonesへ接続する。
5. bufferは256 samplesから開始し、安定すれば128へ下げる。

## Two-Device Setup

H4essentialとPC headphoneなど異なるdeviceを同時使用する場合、ASIO4ALLやVoicemeeter等の
aggregate layerが必要になる場合がある。OS monitorとRenoise monitorを同時に有効化しない。

## Safety

- 初回はMasterとCUEを最小volumeから上げる。
- Turnkey builderのCUE send amountは0から開始する。
- Main/CUEへ同じ物理pairを指定しない。
