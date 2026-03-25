defmodule CSSInlineTest do
  use ExUnit.Case, async: true

  describe "inline/1" do
    test "inlines basic CSS styles" do
      html = """
      <html>
        <head>
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html)
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?red/
    end

    test "handles empty HTML" do
      assert {:ok, result} = CSSInline.inline("")
      assert is_binary(result)
    end

    test "handles HTML without styles" do
      html = "<html><body><p>Hello</p></body></html>"
      assert {:ok, result} = CSSInline.inline(html)
      assert result =~ "Hello"
    end

    test "handles complex CSS selectors" do
      html = """
      <html>
        <head>
          <style>
            .greeting { font-weight: bold; }
            #main { margin: 10px; }
          </style>
        </head>
        <body>
          <p class="greeting">Hello</p>
          <div id="main">Content</div>
        </body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html)
      assert result =~ ~r/font-weight: ?bold/
      assert result =~ ~r/margin: ?10px/
    end

    test "returns an error when NIF encounters invalid inline styles" do
      html = """
      <html>
        <head>
          <style>h1 { background-color: blue; }</style>
        </head>
        <body>
          <h1 style="@wrong {color: ---}">Hello world!</h1>
        </body>
      </html>
      """

      assert {:error, _reason} = CSSInline.inline(html)
    end

    test "minifies CSS output" do
      html = """
      <html>
        <head>
          <style>
            p {
              color:    red;
              margin:   10px;
            }
          </style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html)
      # CSS should be minified (no extra whitespace)
      assert result =~ "color:red" or result =~ "color: red"
    end
  end

  describe "inline/2 with options" do
    test "keep_style_tags: true preserves style tags" do
      html = """
      <html>
        <head>
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html, keep_style_tags: true)
      assert result =~ "<style>"
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?red/
    end

    test "keep_style_tags: false removes style tags (default)" do
      html = """
      <html>
        <head>
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html, keep_style_tags: false)
      refute result =~ "<style>"
    end

    test "inline_style_tags: false skips inlining from style tags" do
      html = """
      <html>
        <head>
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html, inline_style_tags: false)
      # The style should NOT be inlined
      refute result =~ ~r/<p[^>]*style=/
    end

    test "minify_css: false preserves whitespace in CSS" do
      html = """
      <html>
        <head>
          <style>p { color: red; margin: 10px; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html, minify_css: false)
      # With minify_css: false, there should be spaces around colons
      assert result =~ "color: red"
    end

    test "keep_link_tags: true preserves link tags" do
      html = """
      <html>
        <head>
          <link rel="stylesheet" href="https://example.com/style.css">
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} =
               CSSInline.inline(html, keep_link_tags: true, load_remote_stylesheets: false)

      assert result =~ "<link"
    end

    test "load_remote_stylesheets: false skips external stylesheets" do
      html = """
      <html>
        <head>
          <link rel="stylesheet" href="https://example.com/nonexistent.css">
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      # With load_remote_stylesheets: false, this should succeed without trying to fetch
      assert {:ok, result} = CSSInline.inline(html, load_remote_stylesheets: false)
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?red/
    end

    test "multiple options can be combined" do
      html = """
      <html>
        <head>
          <style>p { color: red; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      assert {:ok, result} = CSSInline.inline(html, keep_style_tags: true, minify_css: false)
      assert result =~ "<style>"
      assert result =~ "color: red"
    end
  end

  describe "inline!/2 with options" do
    test "returns inlined HTML on success" do
      html = """
      <html>
        <head>
          <style>p { color: blue; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      result = CSSInline.inline!(html)
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?blue/
    end

    test "accepts options" do
      html = """
      <html>
        <head>
          <style>p { color: blue; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      result = CSSInline.inline!(html, keep_style_tags: true)
      assert result =~ "<style>"
    end

    test "raises on error" do
      html = """
      <html>
        <head>
          <style>h1 { color: blue; }</style>
        </head>
        <body>
          <h1 style="@invalid {color: ---}">Hello!</h1>
        </body>
      </html>
      """

      assert_raise RuntimeError, ~r/CSS inlining failed/, fn ->
        CSSInline.inline!(html)
      end
    end
  end

  describe "!important handling" do
    @email_html """
    <html>
      <head>
        <style>
          a[x-apple-data-detectors],
          u + #body a {
            color: inherit !important;
            text-decoration: none !important;
            font-size: inherit !important;
            font-family: inherit !important;
            font-weight: inherit !important;
            line-height: inherit !important;
          }
          .button a {
            color: #ffffff !important;
            font-size: 16px !important;
            font-weight: bold !important;
          }
        </style>
      </head>
      <body id="body">
        <u>
          <div class="button">
            <a href="https://example.com">Click Me</a>
          </div>
        </u>
      </body>
    </html>
    """

    test "preserves !important when inlining styles" do
      assert {:ok, result} = CSSInline.inline(@email_html)
      assert result =~ ~r/style="[^"]*!important/
    end

    @production_opts [
      load_remote_stylesheets: false,
      keep_link_tags: true,
      keep_style_tags: true
    ]

    test "production settings: inlined selectors remain in <style> without remove_inlined_selectors" do
      assert {:ok, result} = CSSInline.inline(@email_html, @production_opts)

      assert result =~ ~r/style="[^"]*!important/,
             "Inlined styles should preserve !important"

      [_, style_content] = Regex.run(~r/<style[^>]*>(.*?)<\/style>/s, result)

      assert style_content =~ "u + #body a",
             "Non-inlinable selectors should remain in <style> tag"

      assert style_content =~ ".button a",
             "Without remove_inlined_selectors, inlined selectors remain in <style>"
    end

    test "production settings + remove_inlined_selectors strips inlined rules from <style>" do
      {:ok, result} =
        CSSInline.inline(@email_html, [remove_inlined_selectors: true] ++ @production_opts)

      assert result =~ ~r/style="[^"]*color:[^"]*!important/,
             "Inlined styles should preserve !important"

      [_, style_content] = Regex.run(~r/<style[^>]*>(.*?)<\/style>/s, result)

      assert style_content =~ "u + #body a",
             "Non-inlinable selectors (complex email client overrides) must remain"

      refute style_content =~ ".button a",
             "Inlined selectors should be removed from <style> to prevent conflicts"
    end
  end

  describe "regression tests" do
    test "returns error for deeply nested HTML" do
      html = File.read!("test/fixtures/deeply_nested.html")
      assert {:error, :nesting_depth_exceeded} = CSSInline.inline(html)
    end

    test "accepts HTML near but under the nesting limit" do
      divs = String.duplicate("<div>", 100)
      closing = String.duplicate("</div>", 100)

      html =
        "<html><head><style>p{color:red}</style></head><body>#{divs}<p>ok</p>#{closing}</body></html>"

      assert {:ok, result} = CSSInline.inline(html)
      assert result =~ "ok"
    end
  end
end
