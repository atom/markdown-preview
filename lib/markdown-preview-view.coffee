{_, $, $$$, Editor, ScrollView} = require 'atom'
path = require 'path'
roaster = require 'roaster'

fenceNameToExtension =
  'bash': 'sh'
  'coffee': 'coffee'
  'coffeescript': 'coffee'
  'coffee-script': 'coffee'
  'css': 'css'
  'go': 'go'
  'java': 'java'
  'javascript': 'js'
  'js': 'js'
  'json': 'json'
  'less': 'less'
  'mustache': 'mustache'
  'python': 'py'
  'rb': 'rb'
  'ruby': 'rb'
  'sh': 'sh'
  'toml': 'toml'
  'xml': 'xml'

module.exports =
class MarkdownPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: ({filePath}) ->
    new MarkdownPreviewView(filePath)

  @content: ->
    @div class: 'markdown-preview native-key-bindings', tabindex: -1

  initialize: (@filePath) ->
    super
    atom.project.bufferForPath(filePath).done (buffer) =>
      @buffer = buffer
      @renderMarkdown()
      @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderMarkdown()), 250)
      @on 'core:move-up', => @scrollUp()
      @on 'core:move-down', => @scrollDown()
      @subscribe @buffer, 'saved reloaded', =>
        @renderMarkdown()
        pane = @getPane()
        pane.showItem(this) if pane? and pane isnt atom.workspaceView.getActivePane()

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    filePath: @getPath()

  getTitle: ->
    "#{path.basename(@getPath())} Preview"

  getUri: ->
    "markdown-preview:#{@getPath()}"

  getPath: ->
    @filePath

  setErrorHtml: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  setLoading: ->
    @html($$$ -> @div class: 'markdown-spinner', 'Loading Markdown...')

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
      $(preElement).addClass("editor-colors")
      codeBlock = $(preElement.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name matches `lang`
      continue unless extension = fenceNameToExtension[fenceName]
      text = codeBlock.text()

      grammar = atom.syntax.selectGrammar("foo.#{extension}", text)

      codeBlock.empty()
      for tokens in grammar.tokenizeLines(text)
        codeBlock.append(Editor.buildLineHtml({ tokens, text }))

    html

  renderMarkdown: ->
    @setLoading()
    roaster @buffer.getText(), (err, html) =>
      if err
        @setErrorHtml(err)
      else
        @html(@tokenizeCodeBlocks(html))
