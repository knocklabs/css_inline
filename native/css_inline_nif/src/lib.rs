use css_inline::CSSInliner;
use rustler::{Error as RustlerError, NifStruct};

mod atoms {
    rustler::atoms! {
        nesting_depth_exceeded,
    }
}

/// Legitimate email HTML rarely exceeds 30–50 levels. This limit guards
/// against pathological inputs that cause stack overflows in
/// html5ever/cssparser's recursive descent parser.
///
/// Note: the scanner overcounts because void elements (`<br>`, `<img>`, etc.)
/// increment depth but are never closed. Real nesting of ~50 may report ~80-100.
const MAX_NESTING_DEPTH: usize = 128;

/// Returns `true` if the DOM nesting depth exceeds `limit` via a fast byte
/// scan, without parsing. Counts `<x` as an open and `</` as a close;
/// ignores comments and attributes. Returns as soon as the limit is hit.
fn exceeds_nesting_depth(html: &[u8], limit: usize) -> bool {
    let mut depth: usize = 0;
    let mut i = 0;
    while i < html.len() {
        if html[i] == b'<' {
            if i + 1 < html.len() {
                if html[i + 1] == b'/' {
                    // saturating_sub prevents underflow on malformed HTML with unmatched closing tags.
                    depth = depth.saturating_sub(1);
                } else if html[i + 1] != b'!' {
                    depth += 1;
                    if depth > limit {
                        return true;
                    }
                }
            }
            // Skip to end of tag to avoid counting '<' inside attribute values.
            while i < html.len() && html[i] != b'>' {
                i += 1;
            }
        }
        i += 1;
    }
    false
}

/// Options for CSS inlining, mapped from Elixir struct.
#[derive(Debug, NifStruct)]
#[module = "CSSInline.Options"]
struct Options {
    inline_style_tags: bool,
    keep_style_tags: bool,
    keep_link_tags: bool,
    load_remote_stylesheets: bool,
    minify_css: bool,
    max_depth: usize,
}

/// Inlines CSS from `<style>` tags into element `style` attributes.
///
/// # Performance notes
///
/// - **Dirty scheduler**: Runs on a dirty CPU scheduler because CSS inlining can
///   take several milliseconds for large documents. This prevents blocking the
///   main BEAM schedulers which expect NIFs to complete in under 1ms.
///
/// - **Zero-copy input**: Using `&str` allows Rustler to pass a reference directly
///   to the BEAM binary's memory, avoiding a copy on the way in.
///
/// - **Direct buffer write**: Using `inline_to` writes directly to a `Vec<u8>`,
///   avoiding an intermediate `String` allocation that `inline()` would create.
///
/// - **Buffer growth**: The 1.5x pre-allocation is an optimization for typical
///   cases. The `Vec` will automatically grow if the output exceeds this estimate.
///
/// - **Output copy**: The final copy from Rust heap to BEAM heap is unavoidable
///   since BEAM-managed data must live on the BEAM heap.
#[rustler::nif(schedule = "DirtyCpu")]
fn inline_css(html: &str, opts: Options) -> Result<Vec<u8>, RustlerError> {
    let max_depth = if opts.max_depth > 0 {
        opts.max_depth
    } else {
        MAX_NESTING_DEPTH
    };
    if exceeds_nesting_depth(html.as_bytes(), max_depth) {
        return Err(RustlerError::Term(
            Box::new(atoms::nesting_depth_exceeded()),
        ));
    }

    let estimated_size = (html.len() as f64 * 1.5) as usize;
    let mut buffer: Vec<u8> = Vec::with_capacity(estimated_size);
    let inliner = CSSInliner::options()
        .inline_style_tags(opts.inline_style_tags)
        .keep_style_tags(opts.keep_style_tags)
        .keep_link_tags(opts.keep_link_tags)
        .load_remote_stylesheets(opts.load_remote_stylesheets)
        .minify_css(opts.minify_css)
        .build();

    inliner
        .inline_to(html, &mut buffer)
        .map_err(|e| RustlerError::Term(Box::new(format!("CSS inlining failed: {}", e))))?;

    Ok(buffer)
}

rustler::init!("Elixir.CSSInline.Native");
