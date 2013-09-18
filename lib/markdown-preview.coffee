MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    rootView.command 'markdown-preview:show', '.editor', => @show()

  show: ->
    activePane = rootView.getActivePane()
    editSession = activePane.activeItem

    isMarkdownEditor = editSession.getGrammar?()?.scopeName is "source.gfm"
    unless isMarkdownEditor
      console.warn("Can not render markdown for '#{editSession.getUri() ? 'untitled'}'")
      return

    {previewPane, previewItem} = @getExistingPreview(editSession)
    if previewItem?
      previewPane.showItem(previewItem)
      previewItem.renderMarkdown()
    else if nextPane = activePane.getNextPane()
      nextPane.showItem(new MarkdownPreviewView(editSession.buffer))
    else
      activePane.splitRight(new MarkdownPreviewView(editSession.buffer))
    activePane.focus()

  getExistingPreview: (editSession) ->
    uri = "markdown-preview:#{editSession.getPath()}"
    for previewPane in rootView.getPanes()
      previewItem = previewPane.itemForUri(uri)
      return {previewPane, previewItem} if previewItem?
    {}
