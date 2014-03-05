url = require 'url'
fs = require 'fs-plus'

MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'markdown-preview:'

      if host is 'editor'
        new MarkdownPreviewView(editorId: pathname.substring(1))
      else
        new MarkdownPreviewView(filePath: pathname)

  show: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    previousActivePane = atom.workspace.getActivePane()
    uri = "markdown-preview://editor/#{editor.id}"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (markdownPreviewView) ->
      if markdownPreviewView instanceof MarkdownPreviewView
        markdownPreviewView.renderMarkdown()
        previousActivePane.activate()
