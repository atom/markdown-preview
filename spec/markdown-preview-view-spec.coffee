MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "MarkdownPreviewView", ->
  [buffer, preview] = []

  beforeEach ->
    buffer = atom.project.bufferForPathSync('file.markdown')
    atom.packages.activatePackage('language-ruby', sync: true)
    preview = new MarkdownPreviewView(buffer.getPath())

    waitsFor ->
      preview.buffer

  afterEach ->
    buffer.release()

  describe "::constructor", ->
    it "shows a loading spinner and renders the markdown", ->
      preview.showLoading()
      expect(preview.find('.markdown-spinner')).toExist()
      expect(preview.buffer.getText()).toBe buffer.getText()

      preview.renderMarkdown()
      expect(preview.find(".emoji")).toExist()

    it "shows an error message when there is an error", ->
      preview.showError("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    it "reassociates with the same buffer when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      waitsFor ->
        newPreview.buffer

      runs ->
        expect(newPreview.buffer).toBe buffer

  describe "code block tokenization", ->
    describe "when the code block's fence name has a matching grammar", ->
      it "tokenizes the code block with the grammar", ->
        expect(preview.find("pre span.entity.name.function.ruby")).toExist()

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not tokenize the code block", ->
        expect(preview.find("pre code:not([class])").children().length).toBe 0
        expect(preview.find("pre code.lang-kombucha").children().length).toBe 0
