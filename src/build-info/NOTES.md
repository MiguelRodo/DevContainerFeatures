## Providing build info within the container image

This provides the command `/usr/local/bin/container-info` inside the container, which outputs the build details in this format:

```text
--------------------------------------------------
🚀 DevContainer Release Information
--------------------------------------------------
Version: v1.2.3
Built On: 2026-06-12T14:36:22Z
--------------------------------------------------
```

The version and build date are those specified by the feature options.
