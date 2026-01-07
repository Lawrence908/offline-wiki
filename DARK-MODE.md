# Dark Mode Options for Kiwix

Kiwix-serve doesn't have built-in dark mode support, but here are several options to enable it:

## Option 1: Browser Extension (Easiest)

**DarkReader** (recommended):
- Install the [DarkReader browser extension](https://darkreader.org/)
- Works immediately with no configuration
- Supports per-site settings
- Available for Chrome, Firefox, Edge, Safari

**Other options:**
- **Stylus** + custom CSS (more control, requires CSS knowledge)
- **Dark Mode** extensions (various browsers)

## Option 2: Reverse Proxy CSS Injection

If you're using Caddy as a reverse proxy (as suggested in README.md), you can inject dark mode CSS:

### Caddy Configuration

Add to your Caddyfile for `wiki.chrislawrence.ca`:

```caddy
wiki.chrislawrence.ca:80 {
    reverse_proxy offline-wiki:80 {
        header_up Host {host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Inject dark mode CSS
    @html {
        header Content-Type text/html
    }
    replace_response @html '</head>' '<link rel="stylesheet" type="text/css" href="/dark-mode.css"></head>'
    
    # Serve the CSS file
    handle /dark-mode.css {
        file_server
        root * /path/to/kiwix-dark-mode.css
    }
}
```

**Note:** This requires Caddy built with the `replace-response` plugin:
```bash
xcaddy build --with github.com/caddyserver/replace-response
```

### Dark Mode CSS

Create `/path/to/kiwix-dark-mode.css`:

```css
/* Kiwix Dark Mode Styles */
body {
    background-color: #1a1a1a !important;
    color: #e0e0e0 !important;
}

#mw-content-text,
.mw-parser-output,
.content {
    background-color: #1a1a1a !important;
    color: #e0e0e0 !important;
}

a {
    color: #4a9eff !important;
}

a:visited {
    color: #9d4edd !important;
}

.infobox,
.navbox,
.thumb {
    background-color: #2d2d2d !important;
    border-color: #404040 !important;
}

pre,
code {
    background-color: #2d2d2d !important;
    color: #e0e0e0 !important;
}

table {
    background-color: #2d2d2d !important;
}

th {
    background-color: #3d3d3d !important;
}

/* Search box */
input[type="search"],
input[type="text"] {
    background-color: #2d2d2d !important;
    color: #e0e0e0 !important;
    border-color: #404040 !important;
}

/* Navigation */
.navbar,
.sidebar {
    background-color: #1a1a1a !important;
}
```

## Option 3: Client-Side JavaScript Injection

Similar to CSS injection, but using JavaScript for dynamic theme switching. More complex but allows user preference storage.

## Option 4: Wait for Kiwix Updates

Kiwix JS 4.3.0+ and Kiwix PWA 3.0+ have built-in dark mode support, but these are different applications than `kiwix-serve`. If you switch to Kiwix JS/PWA in the future, dark mode will be available natively.

## Recommendation

For now, **Option 1 (Browser Extension)** is the simplest and most reliable solution. It works immediately, requires no server-side changes, and gives users control over their viewing experience.

If you want server-side dark mode for all users, implement **Option 2** when you set up your Caddy reverse proxy.



