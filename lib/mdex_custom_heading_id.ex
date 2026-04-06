defmodule MDExCustomHeadingId do
  @moduledoc ~S"""
  MDEx plugin to support custom heading IDs using `{#id}` syntax.

  Transforms heading Markdown with the widely accepted `{#id}` syntax into a heading HTML
  with the custom ID, optionally prefixed by the `:header_id_prefix` (the new name for
  `:header_ids`) extension option (see `t:MDEx.Document.options/0`). Automatically enables
  unsafe HTML rendering (required for rendering HTML in a plugin).

  The `{#id}` marker must be at the end of the heading and preceded by at least one space.
  IDs may contain only letters, numbers, hyphens, and underscores (a subset of valid HTML
  fragment identifiers).

  Headings that do not contain an ID marker are returned unmodified. Custom ID markers can
  be escaped with `\\{#id}` (backslash before the opening brace) to prevent processing.

  > #### Element ID Uniqueness {: .info}
  >
  > HTML requires element IDs to be unique within a document. This plugin does not
  > validate uniqueness - it's the author's responsibility to ensure custom IDs don't
  > collide with each other or with auto-generated heading IDs from MDEx.

  ## Examples

  ```elixir
  iex> doc = MDEx.new(markdown: ~S"## Match {#custom-id}", plugins: [MDExCustomHeadingId])
  iex> MDEx.to_html!(doc)
  ~S(<h2><a href="#custom-id" aria-hidden="true" class="anchor" id="custom-id"></a>Match</h2>)
  iex> MDEx.to_markdown!(doc)
  ~S(<h2><a href="#custom-id" aria-hidden="true" class="anchor" id="custom-id"></a>Match</h2>)

  # Use `header_ids` with MDEx <= 0.12.0
  iex> doc = MDEx.new(markdown: ~S"## Match {#custom}", plugins: [MDExCustomHeadingId], extension: [header_id_prefix: "user-content-"])
  iex> MDEx.to_html!(doc)
  ~S(<h2><a href="#user-content-custom" aria-hidden="true" class="anchor" id="user-content-custom"></a>Match</h2>)

  iex> doc = MDEx.new(markdown: ~S"## No Match{#custom-id}", plugins: [MDExCustomHeadingId])
  iex> MDEx.to_html!(doc)
  "<h2>No Match{#custom-id}</h2>"
  iex> MDEx.to_markdown!(doc)
  ~S"## No Match{\#custom-id}"

  iex> doc = MDEx.new(markdown: ~S"## No Match `{#custom-id}`", plugins: [MDExCustomHeadingId])
  iex> MDEx.to_html!(doc)
  "<h2>No Match <code>&lbrace;#custom-id&rbrace;</code></h2>"
  iex> MDEx.to_markdown!(doc)
  "## No Match `{#custom-id}`"

  iex> doc = MDEx.new(markdown: ~S"## Escaped \\{#custom-id}", plugins: [MDExCustomHeadingId])
  iex> MDEx.to_html!(doc)
  "<h2>Escaped {#custom-id}</h2>"
  iex> MDEx.to_markdown!(doc)
  ~S"## Escaped {\#custom-id}"
  ```
  """

  alias MDEx.Document

  @doc """
  Attaches the custom heading ID plugin to an MDEx document.

  This is the standard entry point for MDEx plugins. It can be used either in the
  `plugins` option when creating a document, or by calling it directly on a document.

  ## Examples

  ```elixir
  MDEx.new(markdown: ~S"## Heading {#custom-id}")
  |> MDExCustomHeadingId.attach()
  |> MDEx.to_html!()
  ```
  """
  def attach(document, _options \\ []) do
    document
    |> Document.append_steps(custom_header_ids_enable_unsafe: &enable_unsafe/1)
    |> Document.append_steps(custom_header_ids_process: &process_headers/1)
  end

  defp enable_unsafe(document) do
    Document.put_render_options(document, unsafe: true)
  end

  defp process_headers(document) do
    options = Document.get_option(document, :extension, [])

    prefix =
      Keyword.get(options, :header_id_prefix) ||
        Keyword.get(options, :header_ids)

    Document.update_nodes(document, MDEx.Heading, &process_heading(&1, prefix))
  end

  defp process_heading(%MDEx.Heading{nodes: nodes} = heading, prefix) do
    case classify_heading(nodes) do
      # Case 1: No match - do nothing
      :no_match -> heading
      # Case 2: Match - replace with HTML literal block
      {:match, id, nodes} -> render_heading(heading.level, prefix, id, nodes)
      # Case 3: Escaped - remove escape `\`s, return as Markdown heading
      {:escaped, nodes} -> %{heading | nodes: nodes}
    end
  end

  defp render_heading(level, prefix, id, nodes) do
    id = if prefix == "", do: id, else: "#{prefix}#{id}"

    html =
      Enum.join(
        [
          ~s(<h#{level}>),
          ~s(<a href="##{id}" aria-hidden="true" class="anchor" id="#{id}">),
          "</a>",
          render_nodes(nodes),
          ~s(</h#{level}>)
        ],
        ""
      )

    %MDEx.HtmlBlock{literal: html}
  end

  @spec classify_heading([Document.md_node()]) ::
          {:escaped, [Document.md_node()]}
          | {:match, String.t(), [Document.md_node()]}
          | :no_match
  defp classify_heading(nodes) do
    case List.last(nodes) do
      %MDEx.Text{literal: literal} ->
        check_escaped(literal, nodes)

      _ ->
        :no_match
    end
  end

  defp check_escaped(literal, nodes) do
    case Regex.run(~r/^(.*?\s+)\\(\{\s*#[-\w]+\s*\})\s*$/, literal) do
      [_, text_part, braces] ->
        {:escaped, update_last_node(nodes, text_part <> braces)}

      nil ->
        check_match(literal, nodes)
    end
  end

  defp check_match(literal, nodes) do
    case Regex.run(~r/^(.*?)\s+\{\s*#([-\w]+)\s*\}\s*$/, literal) do
      [_, text_part, id] ->
        {:match, id, update_last_node(nodes, String.trim(text_part))}

      nil ->
        :no_match
    end
  end

  defp update_last_node(nodes, new_literal) do
    List.update_at(nodes, -1, fn _ -> %MDEx.Text{literal: new_literal} end)
  end

  defp render_nodes(nodes) do
    nodes
    |> Document.wrap()
    |> MDEx.to_html!()
    |> String.trim()
  end
end
