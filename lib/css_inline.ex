defmodule CSSInline do
  @moduledoc """
  High-performance CSS inlining for HTML documents.

  This library uses a Rust NIF powered by the [css-inline](https://crates.io/crates/css-inline)
  crate to inline CSS from `<style>` tags into element `style` attributes. This is particularly
  useful for preparing HTML emails, which require inline styles for maximum compatibility
  across email clients.

  ## Usage

      iex> html = \"\"\"
      ...> <html>
      ...>   <head>
      ...>     <style>p { color: red; }</style>
      ...>   </head>
      ...>   <body><p>Hello</p></body>
      ...> </html>
      ...> \"\"\"
      iex> {:ok, result} = CSSInline.inline(html)
      iex> result =~ "color"
      true

  ## Options

  The following options can be passed to `inline/2` and `inline!/2`:

    * `:inline_style_tags` - Whether to inline CSS from `<style>` tags. Defaults to `true`.
    * `:keep_style_tags` - Whether to keep `<style>` tags after inlining. Defaults to `false`.
    * `:keep_link_tags` - Whether to keep `<link>` tags after processing. Defaults to `false`.
    * `:load_remote_stylesheets` - Whether to load remote stylesheets referenced in `<link>` tags.
      Defaults to `true`. Set to `false` to skip external stylesheets.
    * `:minify_css` - Whether to minify the inlined CSS. Defaults to `true`.
    * `:remove_inlined_selectors` - Whether to remove selectors from `<style>` tags after they've
      been successfully inlined. Useful with `:keep_style_tags` to avoid conflicts between retained
      `<style>` rules and inlined styles (e.g. `!important` specificity issues in email clients).
      Defaults to `false`.
    * `:check_depth` - Whether to check HTML nesting depth before inlining. Defaults to `true`.
    * `:max_depth` - Maximum allowed HTML nesting depth. Documents exceeding this return
      `{:error, :nesting_depth_exceeded}`. Only applies when `:check_depth` is `true`. Defaults to `128`.

  ## Performance

  The Rust NIF runs on a dirty CPU scheduler to avoid blocking the BEAM's main schedulers,
  as CSS inlining can take several milliseconds for large documents. The implementation
  uses zero-copy input handling and direct buffer writes for optimal performance.
  """

  defmodule Options do
    @moduledoc """
    Options struct for CSS inlining configuration.
    """
    defstruct inline_style_tags: true,
              keep_style_tags: false,
              keep_link_tags: false,
              load_remote_stylesheets: true,
              minify_css: true,
              remove_inlined_selectors: false,
              check_depth: true,
              max_depth: 128

    @type t :: %__MODULE__{
            inline_style_tags: boolean(),
            keep_style_tags: boolean(),
            keep_link_tags: boolean(),
            load_remote_stylesheets: boolean(),
            minify_css: boolean(),
            remove_inlined_selectors: boolean(),
            check_depth: boolean(),
            max_depth: pos_integer()
          }
  end

  @type option ::
          {:inline_style_tags, boolean()}
          | {:keep_style_tags, boolean()}
          | {:keep_link_tags, boolean()}
          | {:load_remote_stylesheets, boolean()}
          | {:minify_css, boolean()}
          | {:remove_inlined_selectors, boolean()}
          | {:check_depth, boolean()}
          | {:max_depth, pos_integer()}

  @doc """
  Inlines CSS from `<style>` tags into element `style` attributes.

  Returns `{:ok, inlined_html}` on success, or `{:error, reason}` on failure.

  ## Options

    * `:inline_style_tags` - Whether to inline CSS from `<style>` tags. Defaults to `true`.
    * `:keep_style_tags` - Whether to keep `<style>` tags after inlining. Defaults to `false`.
    * `:keep_link_tags` - Whether to keep `<link>` tags after processing. Defaults to `false`.
    * `:load_remote_stylesheets` - Whether to load remote stylesheets. Defaults to `true`.
    * `:minify_css` - Whether to minify the inlined CSS. Defaults to `true`.
    * `:remove_inlined_selectors` - Whether to remove selectors from `<style>` tags after they've
      been successfully inlined. Defaults to `false`.
    * `:check_depth` - Whether to check HTML nesting depth before inlining. Defaults to `true`.
    * `:max_depth` - Maximum allowed HTML nesting depth. Defaults to `128`.
  """
  @spec inline(String.t(), [option()]) :: {:ok, String.t()} | {:error, term()}
  def inline(html, opts \\ []) when is_binary(html) and is_list(opts) do
    options = struct(Options, opts)

    case CSSInline.Native.inline_css(html, options) do
      result when is_binary(result) or is_list(result) ->
        {:ok, IO.iodata_to_binary(result)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {e, __STACKTRACE__}}
  end

  @doc """
  Inlines CSS from `<style>` tags into element `style` attributes.

  Returns the inlined HTML on success, or raises an exception on failure.

  ## Options

    * `:inline_style_tags` - Whether to inline CSS from `<style>` tags. Defaults to `true`.
    * `:keep_style_tags` - Whether to keep `<style>` tags after inlining. Defaults to `false`.
    * `:keep_link_tags` - Whether to keep `<link>` tags after processing. Defaults to `false`.
    * `:load_remote_stylesheets` - Whether to load remote stylesheets. Defaults to `true`.
    * `:minify_css` - Whether to minify the inlined CSS. Defaults to `true`.
    * `:remove_inlined_selectors` - Whether to remove selectors from `<style>` tags after they've
      been successfully inlined. Defaults to `false`.
    * `:check_depth` - Whether to check HTML nesting depth before inlining. Defaults to `true`.
    * `:max_depth` - Maximum allowed HTML nesting depth. Defaults to `128`.
  """
  @spec inline!(String.t(), [option()]) :: String.t()
  def inline!(html, opts \\ []) when is_binary(html) and is_list(opts) do
    case inline(html, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "CSS inlining failed: #{inspect(reason)}"
    end
  end
end
