url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, pathname} = url.parse(uriToOpen)
      return unless protocol is 'markdown-preview:' and fs.isFileSync(pathname)
      new MarkdownPreviewView(pathname)

  show: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    unless editor.getGrammar().scopeName is "source.gfm"
      console.warn("Cannot render markdown for '#{editor.getUri() ? 'untitled'}'")
      return

    unless fs.isFileSync(editor.getPath())
      console.warn("Cannot render markdown for '#{editor.getPath() ? 'untitled'}'")
      return

    previousActivePane = atom.workspace.getActivePane()
    uri = "markdown-preview://#{editor.getPath()}"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (markdownPreviewView) ->
      if markdownPreviewView instanceof MarkdownPreviewView
        markdownPreviewView.renderMarkdown()
        previousActivePane.activate()
