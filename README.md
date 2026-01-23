# CSSInline

High-performance CSS inlining for HTML documents using a Rust NIF.

This library inlines CSS from `<style>` tags into element `style` attributes, which is essential for HTML emails where external stylesheets and `<style>` tags are often not supported by email clients.

## Features

- Fast Rust-based CSS inlining using the [css-inline](https://crates.io/crates/css-inline) crate
- Precompiled binaries for common platforms (no Rust toolchain required)
- Runs on dirty CPU scheduler to avoid blocking BEAM schedulers
- CSS minification included
- Zero-copy input handling for optimal performance

## Installation

Add `css_inline` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:css_inline, github: "knocklabs/css_inline"}
  ]
end
```

## Usage

```elixir
html = """
<html>
  <head>
    <style>
      p { color: red; font-weight: bold; }
      .highlight { background-color: yellow; }
    </style>
  </head>
  <body>
    <p>Hello, world!</p>
    <p class="highlight">Important message</p>
  </body>
</html>
"""

{:ok, inlined} = CSSInline.inline(html)
# => {:ok, "<html><head></head><body><p style=\"color:red;font-weight:bold\">..."}

# Or use the bang version that raises on error
inlined = CSSInline.inline!(html)
```

## Precompiled Binaries

This package uses [rustler_precompiled](https://github.com/philss/rustler_precompiled) to provide precompiled NIF binaries for the following platforms:

- `aarch64-apple-darwin` (macOS Apple Silicon)
- `x86_64-apple-darwin` (macOS Intel)
- `aarch64-unknown-linux-gnu` (Linux ARM64 GNU)
- `aarch64-unknown-linux-musl` (Linux ARM64 musl)
- `x86_64-unknown-linux-gnu` (Linux x86_64 GNU)
- `x86_64-unknown-linux-musl` (Linux x86_64 musl)

### Building from source

If you need to compile from source (e.g., for a platform without precompiled binaries), ensure you have Rust installed and set the environment variable:

```bash
export CSS_INLINE_BUILD=true
mix deps.compile css_inline --force
```

## Performance

The Rust NIF is configured to run on a dirty CPU scheduler because CSS inlining can take several milliseconds for large documents. This prevents blocking the main BEAM schedulers which expect NIFs to complete in under 1ms.

Additional performance optimizations include:

- **Zero-copy input**: Uses `&str` to pass references directly to BEAM binary memory
- **Direct buffer write**: Writes directly to a `Vec<u8>` avoiding intermediate allocations
- **Buffer pre-allocation**: Pre-allocates 1.5x the input size for typical cases
- **CSS minification**: Output CSS is automatically minified

## License

MIT License - see [LICENSE](LICENSE) for details.
