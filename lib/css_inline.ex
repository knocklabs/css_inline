defmodule CssInline do
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
      iex> {:ok, result} = CssInline.inline(html)
      iex> result =~ "color"
      true

  ## Performance

  The Rust NIF runs on a dirty CPU scheduler to avoid blocking the BEAM's main schedulers,
  as CSS inlining can take several milliseconds for large documents. The implementation
  uses zero-copy input handling and direct buffer writes for optimal performance.
  """

  @doc """
  Inlines CSS from `<style>` tags into element `style` attributes.

  Returns `{:ok, inlined_html}` on success, or `{:error, reason}` on failure.
  """
  @spec inline(String.t()) :: {:ok, String.t()} | {:error, term()}
  def inline(html) when is_binary(html) do
    case CssInline.Native.inline_css(html) do
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
  """
  @spec inline!(String.t()) :: String.t()
  def inline!(html) when is_binary(html) do
    case inline(html) do
      {:ok, result} -> result
      {:error, reason} -> raise "CSS inlining failed: #{inspect(reason)}"
    end
  end
end
