MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', '.editor', => @show()

  show: ->
    activePane = atom.workspaceView.getActivePane()
    editSession = activePane.activeItem

    isMarkdownEditor = editSession.getGrammar?()?.scopeName is "source.gfm"
    unless isMarkdownEditor
      console.warn("Can not render markdown for '#{editSession.getUri() ? 'untitled'}'")
      return

    {previewPane, previewItem} = @getExistingPreview(editSession)
    filePath = editSession.getPath()
    if previewItem?
      previewPane.showItem(previewItem)
      previewItem.renderMarkdown()
    else if nextPane = activePane.getNextPane()
      nextPane.showItem(new MarkdownPreviewView(filePath))
    else
      activePane.splitRight(new MarkdownPreviewView(filePath))
    activePane.focus()

  getExistingPreview: (editSession) ->
    uri = "markdown-preview:#{editSession.getPath()}"
    for previewPane in atom.workspaceView.getPanes()
      previewItem = previewPane.itemForUri(uri)
      return {previewPane, previewItem} if previewItem?
    {}
