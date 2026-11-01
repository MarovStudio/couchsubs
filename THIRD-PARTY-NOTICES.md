# Third-party notices / Üçüncü taraf bileşenler

CouchSubs is licensed under the GNU AGPL-3.0 (see [LICENSE](LICENSE)). It includes or downloads the
following third-party components. Full source code for CouchSubs, including the build scripts that
produce the bundled libraries, is available at https://github.com/yorulmazsinan/couchsubs.

## Bundled in the Mac and Windows apps

| Component | License | Source |
|---|---|---|
| chiaki-ng (`libchiaki`, Remote Play) | AGPL-3.0 with OpenSSL exception | https://github.com/chiaki-ng/chiaki-ng |
| nanopb | zlib | https://github.com/nanopb/nanopb |
| Jerasure | BSD-3-Clause | https://github.com/ceph/jerasure |
| GF-Complete | BSD-3-Clause | https://github.com/ceph/gf-complete |
| curl | curl license (MIT/X derivative) | https://curl.se |
| OpenSSL 3 | Apache-2.0 | https://www.openssl.org |
| json-c | MIT | https://github.com/json-c/json-c |
| libevent | BSD-3-Clause | https://libevent.org |
| miniupnpc | BSD-3-Clause | https://miniupnp.tuxfamily.org |

## Windows app only

| Component | License | Source |
|---|---|---|
| FFmpeg 7.1.2 (`libavcodec` H.264 decoder, `libswscale`; statically linked) | LGPL-2.1-or-later | https://ffmpeg.org |
| .NET runtime and WPF | MIT | https://github.com/dotnet |
| ONNX Runtime | MIT | https://github.com/microsoft/onnxruntime |
| Microsoft.ML.Tokenizers | MIT | https://github.com/dotnet/machinelearning |
| System.Security.Cryptography.ProtectedData | MIT | https://github.com/dotnet/runtime |
| Microsoft WebView2 SDK | BSD-3-Clause | https://www.nuget.org/packages/Microsoft.Web.WebView2 |

FFmpeg is built from the unmodified upstream release with the configuration in
`.github/workflows/windows.yml`. You can rebuild `couchsubs_native.dll` with your own FFmpeg build using
`windows/native/CMakeLists.txt` and place it next to `CouchSubs.exe`.

## Downloaded on first use (Windows)

| Component | License | Source |
|---|---|---|
| OPUS-MT English→Turkish translation model (`opus-mt-tc-big-en-tr`, ONNX export) | CC BY 4.0 | Language Technology Research Group, University of Helsinki — https://huggingface.co/Helsinki-NLP/opus-mt-tc-big-en-tr, ONNX conversion https://huggingface.co/onnx-community/opus-mt-tc-big-en-tr |

The model is used unmodified (int8 quantised ONNX files as published by onnx-community).

## Mac app

Text recognition (Vision) and translation (Translation framework) are provided by macOS.

## Trademarks

CouchSubs is not affiliated with or endorsed by Sony Interactive Entertainment. "PlayStation" and "PS5"
are trademarks of Sony Interactive Entertainment Inc. LG and webOS are trademarks of LG Electronics Inc.
