use css_inline::CSSInliner;
use rustler::Error as RustlerError;

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
fn inline_css(html: &str) -> Result<Vec<u8>, RustlerError> {
    let estimated_size = (html.len() as f64 * 1.5) as usize;
    let mut buffer: Vec<u8> = Vec::with_capacity(estimated_size);
    let inliner = CSSInliner::options().minify_css(true).build();

    inliner
        .inline_to(html, &mut buffer)
        .map_err(|e| RustlerError::Term(Box::new(format!("CSS inlining failed: {}", e))))?;

    Ok(buffer)
}

rustler::init!("Elixir.CSSInline.Native");
