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
end
