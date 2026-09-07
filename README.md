# morphe-patch-builder
GitHub Actions builder untuk Morphe APK (YT/YTM stable + experimental base).

- Trigger: manual (`workflow_dispatch`) atau schedule Minggu 19:00 UTC (Senin 02:00 WIB)
- Output: upload langsung ke `gdrive:Aplikasi Premium/{YT,YTM}/{Stable,Experimental}/`
- Secrets: `MORPHE_KEYSTORE_B64`, `RCLONE_CONF_B64`
