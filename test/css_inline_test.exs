defmodule CssInlineTest do
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

      assert {:ok, result} = CssInline.inline(html)
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?red/
    end

    test "handles empty HTML" do
      assert {:ok, result} = CssInline.inline("")
      assert is_binary(result)
    end

    test "handles HTML without styles" do
      html = "<html><body><p>Hello</p></body></html>"
      assert {:ok, result} = CssInline.inline(html)
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

      assert {:ok, result} = CssInline.inline(html)
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

      assert {:error, _reason} = CssInline.inline(html)
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

      assert {:ok, result} = CssInline.inline(html)
      # CSS should be minified (no extra whitespace)
      assert result =~ "color:red" or result =~ "color: red"
    end
  end

  describe "inline!/1" do
    test "returns inlined HTML on success" do
      html = """
      <html>
        <head>
          <style>p { color: blue; }</style>
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      result = CssInline.inline!(html)
      assert result =~ ~r/<p[^>]*style="[^"]*color: ?blue/
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
        CssInline.inline!(html)
      end
    end
  end
end
