use css_inline::CSSInliner;
use rustler::{Error as RustlerError, NifStruct};

/// Options for CSS inlining, mapped from Elixir struct.
#[derive(Debug, NifStruct)]
#[module = "CSSInline.Options"]
struct Options {
    inline_style_tags: bool,
    keep_style_tags: bool,
    keep_link_tags: bool,
    load_remote_stylesheets: bool,
    minify_css: bool,
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
    std::panic::catch_unwind(|| {
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
    })
    .map_err(|e| {
        let msg = e
            .downcast_ref::<String>()
            .map(|s| s.as_str())
            .or_else(|| e.downcast_ref::<&str>().copied())
            .unwrap_or("unknown panic");
        RustlerError::Term(Box::new(format!("NIF panic: {}", msg)))
    })?
}

rustler::init!("Elixir.CSSInline.Native");
