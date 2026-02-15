defmodule MDExCustomHeadingIdTest do
  use ExUnit.Case, async: true

  doctest MDExCustomHeadingId

  describe "basic custom ID" do
    test "extracts and applies custom ID" do
      html = MDEx.to_html!("# Title {#custom}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="custom")
      assert html =~ ~s(href="#custom")
      assert html =~ "Title"
      refute html =~ "{#custom}"
    end

    test "works with different heading levels" do
      for level <- 1..6 do
        markdown = String.duplicate("#", level) <> " Heading {#test}"
        html = MDEx.to_html!(markdown, plugins: [MDExCustomHeadingId])

        assert html =~ ~s(<h#{level}>)
        assert html =~ ~s(id="test")
      end
    end

    test "requires whitespace before opening brace" do
      html = MDEx.to_html!("# Title{#nospace}", plugins: [MDExCustomHeadingId])

      # Should not match - passes through as normal heading
      refute html =~ ~s(id="nospace")
      assert html =~ "Title{#nospace}"
    end

    test "allows whitespace inside braces" do
      html = MDEx.to_html!("# Title { #spaced }", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="spaced")
      assert html =~ "Title"
      refute html =~ "{ #spaced }"
    end

    test "must be at end of heading" do
      html = MDEx.to_html!("# Title {#id} extra text", plugins: [MDExCustomHeadingId])

      # Should not match - not at end
      refute html =~ ~s(id="id")
      assert html =~ "Title {#id} extra text"
    end
  end

  describe "ID prefix support" do
    test "applies configured prefix to custom ID" do
      html =
        MDEx.to_html!("# Title {#custom}",
          extension: [header_ids: "user-content-"],
          plugins: [MDExCustomHeadingId]
        )

      assert html =~ ~s(id="user-content-custom")
      assert html =~ ~s(href="#user-content-custom")
    end

    test "works without prefix" do
      html =
        MDEx.to_html!("# Title {#custom}",
          extension: [header_ids: ""],
          plugins: [MDExCustomHeadingId]
        )

      assert html =~ ~s(id="custom")
      refute html =~ "user-content-"
    end
  end

  describe "inline formatting" do
    test "preserves bold text" do
      html = MDEx.to_html!("# **Bold** Title {#bold}", plugins: [MDExCustomHeadingId])

      assert html =~ "<strong>Bold</strong>"
      assert html =~ ~s(id="bold")
    end

    test "preserves italic text" do
      html = MDEx.to_html!("# *Italic* Title {#italic}", plugins: [MDExCustomHeadingId])

      assert html =~ "<em>Italic</em>"
      assert html =~ ~s(id="italic")
    end

    test "preserves code" do
      html = MDEx.to_html!("# Using `code` {#code}", plugins: [MDExCustomHeadingId])

      assert html =~ "<code>code</code>"
      assert html =~ ~s(id="code")
    end

    test "preserves strikethrough" do
      html =
        MDEx.to_html!("# ~~Strike~~ {#strike}",
          extension: [strikethrough: true],
          plugins: [MDExCustomHeadingId]
        )

      assert html =~ "<del>Strike</del>"
      assert html =~ ~s(id="strike")
    end

    test "preserves mixed formatting" do
      html = MDEx.to_html!("# **Bold** and *italic* with `code` {#mixed}", plugins: [MDExCustomHeadingId])

      assert html =~ "<strong>Bold</strong>"
      assert html =~ "<em>italic</em>"
      assert html =~ "<code>code</code>"
      assert html =~ ~s(id="mixed")
    end
  end

  describe "links in headings" do
    test "preserves inline links without nesting anchors" do
      html = MDEx.to_html!("# Title with [link](https://example.com) {#test}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="test")
      assert html =~ ~s(<a href="https://example.com">link</a>)
      # Verify no nested anchors - both should be siblings
      assert html =~ ~r/<h1>\s*<a[^>]*id="test"[^>]*><\/a>.*<a[^>]*href="https:\/\/example\.com"/s
    end

    test "handles heading that is entirely a link" do
      html = MDEx.to_html!("# [GitHub](https://github.com) {#gh}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="gh")
      assert html =~ ~s(<a href="https://github.com">GitHub</a>)
    end

    test "handles link at start of heading" do
      html = MDEx.to_html!("# [Link](https://example.com) and text {#test}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="test")
      assert html =~ ~s(<a href="https://example.com">Link</a>)
      assert html =~ "and text"
    end

    test "resolves reference links" do
      markdown = """
      # Title with [ref link][ref] {#test}

      [ref]: https://example.com
      """

      html = MDEx.to_html!(markdown, plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="test")
      assert html =~ ~s(<a href="https://example.com">ref link</a>)
    end
  end

  describe "footnotes in headings" do
    test "preserves footnote references" do
      markdown = """
      # Title with footnote[^1] {#test}

      [^1]: This is a footnote
      """

      html =
        MDEx.to_html!(markdown,
          extension: [footnotes: true],
          plugins: [MDExCustomHeadingId]
        )

      assert html =~ ~s(id="test")
      assert html =~ ~s(<sup class="footnote-ref">)
      assert html =~ ~s(<a href="#fn-1")
      assert html =~ ~s(id="fnref-1")
    end

    test "footnote at end with custom id" do
      markdown = """
      # Title text[^note] {#custom}

      [^note]: Footnote content
      """

      html =
        MDEx.to_html!(markdown,
          extension: [footnotes: true],
          plugins: [MDExCustomHeadingId]
        )

      assert html =~ ~s(id="custom")
      assert html =~ ~s(href="#custom")
      assert html =~ "Title text"
      assert html =~ ~s(<sup class="footnote-ref">)
    end
  end

  describe "escaped custom ID" do
    test "removes backslash and does not apply custom ID" do
      html = MDEx.to_html!(~S"# Header \\{#not-id}", plugins: [MDExCustomHeadingId])

      assert html =~ "Header {#not-id}"
      refute html =~ ~s(id="not-id")
      # Should be a normal heading, not our custom HTML
      assert html =~ ~r/<h1[^>]*>Header \{#not-id\}<\/h1>/
    end

    test "escaped ID with whitespace" do
      html = MDEx.to_html!(~S"# Header \\{ #not-id }", plugins: [MDExCustomHeadingId])

      assert html =~ "Header { #not-id }"
      refute html =~ ~s(id="not-id")
    end
  end

  describe "no custom ID" do
    test "passes through normal headings unchanged" do
      html = MDEx.to_html!("# Normal Heading", plugins: [MDExCustomHeadingId])

      assert html =~ "Normal Heading"
      # Should be normal MDEx output
      assert html =~ ~r/<h1[^>]*>Normal Heading<\/h1>/
    end

    test "passes through headings with closing hashes" do
      html = MDEx.to_html!("# Heading #", plugins: [MDExCustomHeadingId])

      assert html =~ "Heading"
      refute html =~ "#"
    end
  end

  describe "HTML output format" do
    test "matches MDEx/comrak default structure" do
      html = MDEx.to_html!("# Title {#test}", plugins: [MDExCustomHeadingId])

      # Anchor should be first, empty, with aria-hidden
      assert html =~ ~r/<h1>\s*<a href="#test" aria-hidden="true" class="anchor" id="test"><\/a>/
    end

    test "includes aria-hidden on anchor" do
      html = MDEx.to_html!("# Title {#test}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(aria-hidden="true")
    end

    test "includes anchor class" do
      html = MDEx.to_html!("# Title {#test}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(class="anchor")
    end

    test "ID is on anchor, not heading" do
      html = MDEx.to_html!("# Title {#test}", plugins: [MDExCustomHeadingId])

      # ID should be on the <a> tag
      assert html =~ ~r/<a[^>]*id="test"/
      # Not on the <h1> tag
      refute html =~ ~r/<h1[^>]*id=/
    end
  end

  describe "multiple headings" do
    test "processes multiple headings independently" do
      markdown = """
      # First {#first}

      ## Second {#second}

      ### Third {#third}
      """

      html = MDEx.to_html!(markdown, plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="first")
      assert html =~ ~s(id="second")
      assert html =~ ~s(id="third")
      assert html =~ "<h1>"
      assert html =~ "<h2>"
      assert html =~ "<h3>"
    end

    test "mixes custom and normal headings" do
      markdown = """
      # Custom {#custom}

      ## Normal

      ### Another Custom {#another}
      """

      html = MDEx.to_html!(markdown, plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="custom")
      assert html =~ ~s(id="another")
      assert html =~ "Normal"
    end
  end

  describe "edge cases" do
    test "handles empty heading text" do
      html = MDEx.to_html!("# {#empty}", plugins: [MDExCustomHeadingId])

      # Should not match - no text before {#id}
      refute html =~ ~s(id="empty")
    end

    test "handles very long IDs" do
      long_id = String.duplicate("a", 100)
      html = MDEx.to_html!("# Title {##{long_id}}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="#{long_id}")
    end

    test "handles IDs with hyphens and underscores" do
      html = MDEx.to_html!("# Title {#my-custom_id-123}", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="my-custom_id-123")
    end

    test "handles trailing whitespace after closing brace" do
      html = MDEx.to_html!("# Title {#test}   ", plugins: [MDExCustomHeadingId])

      assert html =~ ~s(id="test")
      assert html =~ "Title"
    end
  end

  describe "unsafe rendering" do
    test "plugin enables unsafe rendering automatically" do
      # The plugin should set unsafe: true so HTML blocks are rendered
      html = MDEx.to_html!("# Title {#test}", plugins: [MDExCustomHeadingId])

      # Should contain our custom HTML, not escaped
      assert html =~ ~s(<h1>)
      assert html =~ ~s(<a href="#test")
      refute html =~ "&lt;"
    end
  end
end
