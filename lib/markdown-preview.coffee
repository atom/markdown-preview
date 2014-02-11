MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.project.registerOpener (uriToOpen) ->
      fs = require 'fs-plus'
      url = require 'url'

      {protocol, pathname} = url.parse(uriToOpen)
      return unless protocol is 'markdown-preview:' and fs.isFileSync(pathname)
      new MarkdownPreviewView(pathname)

  show: ->
    paneView = atom.workspaceView.getActivePaneView()
    editor = paneView.getActiveItem()

    unless editor.getGrammar?().scopeName is "source.gfm"
      console.warn("Can not render markdown for '#{editor.getUri() ? 'untitled'}'")
      return

    uri = "markdown-preview://#{editor.getPath()}"
    atom.workspace.open(uri, split: 'right').done (markdownPreviewView) ->
      markdownPreviewView.renderMarkdown()
      paneView.focus()
