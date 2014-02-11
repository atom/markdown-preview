path = require 'path'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "MarkdownPreviewView", ->
  [file, preview] = []

  beforeEach ->
    filePath = atom.project.resolve('file.markdown')
    preview = new MarkdownPreviewView(filePath)

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

  afterEach ->
    preview.destroy()

  describe "::constructor", ->
    it "shows a loading spinner and renders the markdown", ->
      preview.showLoading()
      expect(preview.find('.markdown-spinner')).toExist()

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        expect(preview.find(".emoji")).toExist()

    it "shows an error message when there is an error", ->
      preview.showError("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    newPreview = null

    afterEach ->
      newPreview.destroy()

    it "recreates the file when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      expect(newPreview.getPath()).toBe preview.getPath()

  describe "code block tokenization", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderMarkdown()

    describe "when the code block's fence name has a matching grammar", ->
      it "tokenizes the code block with the grammar", ->
        expect(preview.find("pre span.entity.name.function.ruby")).toExist()

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not tokenize the code block", ->
        expect(preview.find("pre code:not([class])").children().length).toBe 0
        expect(preview.find("pre code.lang-kombucha").children().length).toBe 0
