url = require 'url'
{fs} = require 'atom'
MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    atom.workspaceView.command 'markdown-preview:show', =>
      @show()

    atom.project.registerOpener (urlToOpen) ->
      {protocol, pathname} = url.parse(urlToOpen)
      return unless protocol is 'markdown-preview:' and fs.isFileSync(pathname)
      new MarkdownPreviewView(pathname)

  show: ->
    activePane = atom.workspaceView.getActivePane()
    editor = activePane.activeItem

    unless editor.getGrammar?().scopeName is "source.gfm"
      console.warn("Can not render markdown for '#{editor.getUri() ? 'untitled'}'")
      return

    markdownUrl = "markdown-preview://#{editor.getPath()}"
    atom.workspace.openSingletonSync(markdownUrl, split: 'right')
    activePane.focus()
