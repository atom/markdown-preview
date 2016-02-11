path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "MarkdownPreviewView", ->
  [file, preview, workspaceElement] = []

  beforeEach ->
    filePath = atom.project.getDirectories()[0].resolve('subdir/file.markdown')
    preview = new MarkdownPreviewView({filePath})
    jasmine.attachToDOM(preview.element)

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('markdown-preview')

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
      newPreview?.destroy()

    it "recreates the preview when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      jasmine.attachToDOM(newPreview.element)
      expect(newPreview.getPath()).toBe preview.getPath()

    it "does not recreate a preview when the file no longer exists", ->
      filePath = path.join(temp.mkdirSync('markdown-preview-'), 'foo.md')
      fs.writeFileSync(filePath, '# Hi')

      preview.destroy()
      preview = new MarkdownPreviewView({filePath})
      serialized = preview.serialize()
      fs.removeSync(filePath)

      newPreview = atom.deserializers.deserialize(serialized)
      expect(newPreview).toBeUndefined()

    it "serializes the editor id when opened for an editor", ->
      preview.destroy()

      waitsForPromise ->
        atom.workspace.open('new.markdown')

      runs ->
        preview = new MarkdownPreviewView({editorId: atom.workspace.getActiveTextEditor().id})

        jasmine.attachToDOM(preview.element)
        expect(preview.getPath()).toBe atom.workspace.getActiveTextEditor().getPath()

        newPreview = atom.deserializers.deserialize(preview.serialize())
        jasmine.attachToDOM(newPreview.element)
        expect(newPreview.getPath()).toBe preview.getPath()

  describe "code block conversion to atom-text-editor tags", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderMarkdown()

    it "removes line decorations on rendered code blocks", ->
      editor = preview.find("atom-text-editor[data-grammar='text plain null-grammar']")
      decorations = editor[0].getModel().getDecorations(class: 'cursor-line', type: 'line')
      expect(decorations.length).toBe 0

    describe "when the code block's fence name has a matching grammar", ->
      it "assigns the grammar on the atom-text-editor", ->
        rubyEditor = preview.find("atom-text-editor[data-grammar='source ruby']")
        expect(rubyEditor).toExist()
        expect(rubyEditor[0].getModel().getText()).toBe """
          def func
            x = 1
          end
        """

        # nested in a list item
        jsEditor = preview.find("atom-text-editor[data-grammar='source js']")
        expect(jsEditor).toExist()
        expect(jsEditor[0].getModel().getText()).toBe """
          if a === 3 {
          b = 5
          }
        """

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not assign a specific grammar", ->
        plainEditor = preview.find("atom-text-editor[data-grammar='text plain null-grammar']")
        expect(plainEditor).toExist()
        expect(plainEditor[0].getModel().getText()).toBe """
          function f(x) {
            return x++;
          }
        """

  describe "image resolving", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderMarkdown()

    describe "when the image uses a relative path", ->
      it "resolves to a path relative to the file", ->
        image = preview.find("img[alt=Image1]")
        expect(image.attr('src')).toBe atom.project.getDirectories()[0].resolve('subdir/image1.png')

    describe "when the image uses an absolute path that does not exist", ->
      it "resolves to a path relative to the project root", ->
        image = preview.find("img[alt=Image2]")
        expect(image.attr('src')).toBe atom.project.getDirectories()[0].resolve('tmp/image2.png')

    describe "when the image uses an absolute path that exists", ->
      it "doesn't change the URL", ->
        preview.destroy()

        filePath = path.join(temp.mkdirSync('atom'), 'foo.md')
        fs.writeFileSync(filePath, "![absolute](#{filePath})")
        preview = new MarkdownPreviewView({filePath})
        jasmine.attachToDOM(preview.element)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.find("img[alt=absolute]").attr('src')).toBe filePath

    describe "when the image uses a web URL", ->
      it "doesn't change the URL", ->
        image = preview.find("img[alt=Image3]")
        expect(image.attr('src')).toBe 'http://github.com/image3.png'

  describe "gfm newlines", ->
    describe "when gfm newlines are not enabled", ->
      it "creates a single paragraph with <br>", ->
        atom.config.set('markdown-preview.breakOnSingleNewline', false)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.find("p:last-child br").length).toBe 0

    describe "when gfm newlines are enabled", ->
      it "creates a single paragraph with no <br>", ->
        atom.config.set('markdown-preview.breakOnSingleNewline', true)

        waitsForPromise ->
          preview.renderMarkdown()

        runs ->
          expect(preview.find("p:last-child br").length).toBe 1

  describe "when core:save-as is triggered", ->
    beforeEach ->
      preview.destroy()
      filePath = atom.project.getDirectories()[0].resolve('subdir/code-block.md')
      preview = new MarkdownPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

    it "saves the rendered HTML and opens it", ->
      outputPath = temp.path(suffix: '.html')
      expectedFilePath = atom.project.getDirectories()[0].resolve('saved-html.html')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()

      createRule = (selector, css) ->
        return {
          selectorText: selector
          cssText: "#{selector} #{css}"
        }

      markdownPreviewStyles = [
        {
          rules: [
            createRule ".markdown-preview", "{ color: orange; }"
          ]
        }, {
          rules: [
            createRule ".not-included", "{ color: green; }"
            createRule ".markdown-preview :host", "{ color: purple; }"
          ]
        }
      ]

      atomTextEditorStyles = [
        "atom-text-editor .line { color: brown; }\natom-text-editor .number { color: cyan; }"
        "atom-text-editor :host .something { color: black; }"
        "atom-text-editor .hr { background: url(atom://markdown-preview/assets/hr.png); }"
      ]

      expect(fs.isFileSync(outputPath)).toBe false

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        spyOn(preview, 'getDocumentStyleSheets').andReturn(markdownPreviewStyles)
        spyOn(preview, 'getTextEditorStyles').andReturn(atomTextEditorStyles)
        atom.commands.dispatch preview.element, 'core:save-as'

      waitsFor ->
        fs.existsSync(outputPath) and atom.workspace.getActiveTextEditor()?.getPath() is fs.realpathSync(outputPath)

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

    describe "text editor style extraction", ->

      [extractedStyles] = []

      textEditorStyle = ".editor-style .extraction-test { color: blue; }"
      unrelatedStyle  = ".something else { color: red; }"

      beforeEach ->
        atom.styles.addStyleSheet textEditorStyle,
          context: 'atom-text-editor'

        atom.styles.addStyleSheet unrelatedStyle,
          context: 'unrelated-context'

        extractedStyles = preview.getTextEditorStyles()

      it "returns an array containing atom-text-editor css style strings", ->
        expect(extractedStyles.indexOf(textEditorStyle)).toBeGreaterThan(-1)

      it "does not return other styles", ->
        expect(extractedStyles.indexOf(unrelatedStyle)).toBe(-1)

  describe "when core:copy is triggered", ->
    it "writes the rendered HTML to the clipboard", ->
      preview.destroy()
      preview.element.remove()

      filePath = atom.project.getDirectories()[0].resolve('subdir/code-block.md')
      preview = new MarkdownPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

      waitsForPromise ->
        preview.renderMarkdown()

      runs ->
        atom.commands.dispatch preview.element, 'core:copy'

      waitsFor ->
        atom.clipboard.read() isnt "initial clipboard content"

      runs ->
        expect(atom.clipboard.read()).toBe """
         <h1 id="code-block">Code Block</h1>
         <pre class="editor-colors lang-javascript"><div class="line"><span class="source js"><span class="keyword control js"><span>if</span></span><span>&nbsp;a&nbsp;</span><span class="keyword operator comparison js"><span>===</span></span><span>&nbsp;</span><span class="constant numeric js"><span>3</span></span><span>&nbsp;</span><span class="meta brace curly js"><span>{</span></span></span></div><div class="line"><span class="source js"><span>&nbsp;&nbsp;b&nbsp;</span><span class="keyword operator assignment js"><span>=</span></span><span>&nbsp;</span><span class="constant numeric js"><span>5</span></span></span></div><div class="line"><span class="source js"><span class="meta brace curly js"><span>}</span></span></span></div></pre>
         <p>encoding \u2192 issue</p>
        """
