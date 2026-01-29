defmodule CSSInline.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :css_inline,
    crate: "css_inline_nif",
    base_url: "https://github.com/knocklabs/css_inline/releases/download/v#{version}",
    force_build: System.get_env("CSS_INLINE_BUILD") in ["1", "true"],
    version: version,
    targets: ~w(
      aarch64-apple-darwin
      aarch64-unknown-linux-gnu
      aarch64-unknown-linux-musl
      x86_64-apple-darwin
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl
    )

  # NIF function - will be replaced at runtime by the Rust implementation.
  # This stub is only used if the NIF fails to load.
  def inline_css(_html, _opts), do: :erlang.nif_error(:nif_not_loaded)
end
