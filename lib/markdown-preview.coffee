url = require 'url'
{fs} = require 'atom'
MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', => @show()

    atom.project.registerOpener (uriToOpen) ->
      {protocol, pathname} = url.parse(uriToOpen)
      if protocol is 'markdown-preview:' and fs.isFileSync(pathname)
        new MarkdownPreviewView(pathname)

  show: ->
    activePane = atom.workspaceView.getActivePane()
    editor = activePane.activeItem

    isMarkdownEditor = editor.getGrammar?()?.scopeName is "source.gfm"
    unless isMarkdownEditor
      console.warn("Can not render markdown for '#{editor.getUri() ? 'untitled'}'")
      return

    {previewPane, previewItem} = @getExistingPreview(editor)
    filePath = editor.getPath()
    if previewItem?
      previewPane.showItem(previewItem)
      previewItem.renderMarkdown()
    else if nextPane = activePane.getNextPane()
      nextPane.showItem(new MarkdownPreviewView(filePath))
    else
      activePane.splitRight(new MarkdownPreviewView(filePath))
    activePane.focus()

  getExistingPreview: (editor) ->
    uri = "markdown-preview://#{editor.getPath()}"
    for previewPane in atom.workspaceView.getPanes()
      previewItem = previewPane.itemForUri(uri)
      return {previewPane, previewItem} if previewItem?
    {}
