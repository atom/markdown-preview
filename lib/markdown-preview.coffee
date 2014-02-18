MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.workspace.registerOpener (uriToOpen) ->
      fs = require 'fs-plus'
      url = require 'url'

      {protocol, pathname} = url.parse(uriToOpen)
      return unless protocol is 'markdown-preview:' and fs.isFileSync(pathname)
      new MarkdownPreviewView(pathname)

  show: ->
    editor = atom.workspace.getActiveEditor()
    unless editor? and editor.getGrammar().scopeName is "source.gfm"
      console.warn("Can not render markdown for '#{editor?.getUri() ? 'untitled'}'")
      return

    previousActivePaneView = atom.workspaceView.getActivePaneView()
    uri = "markdown-preview://#{editor.getPath()}"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (markdownPreviewView) ->
      markdownPreviewView.renderMarkdown()
      previousActivePaneView.focus()
