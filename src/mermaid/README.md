# Mermaid (mermaid)

Installs Mermaid CLI to generate diagrams from `.mmd` files. Sets up a non-root user and Puppeteer configuration for headless rendering.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/mermaid:1": {}
}
```

## Options

| Option | Description | Type | Default |
|---|---|---|---|
| userName | Specify the username under which Mermaid CLI will run. | string | "mermaiduser" |
| puppeteerConfigDir | Directory to store Puppeteer configuration files. | string | "/usr/local/share/mermaid-config" |
| nodeVersion | Node.js version to install if missing (e.g. "lts", "20"). | string | "lts" |

## Notes

- This feature requires Node.js. If not present, it will attempt to install the specified version.
- It installs system dependencies required for Puppeteer.
