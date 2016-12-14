class ExternalDoc
  def self.fetch(url_to_markdown)
    markdown = Faraday.get(url_to_markdown).body

    # remove the own title of the page
    markdown = markdown.lines[2..-1].join.strip

    # Make sure we link to the pages hosted here
    markdown = markdown.gsub('.md', '.html')

    markdown
  end
end