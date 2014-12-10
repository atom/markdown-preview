path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "Markdown preview package", ->
  workspaceElement = null

  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPaths([tempPath])
    jasmine.unspy(window, 'setTimeout')

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown').andCallThrough()

    waitsForPromise ->
      atom.packages.activatePackage("markdown-preview")

    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')

  describe "when a preview has not been created for the file", ->
    it "splits the current pane to the right with a markdown preview for the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.commands.dispatch atom.views.getView(atom.workspace.getActivePaneItem()), 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspace.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspace.getPanes()

        expect(editorPane.getItems()).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
        expect(editorPane.isActive()).toBe true

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("new.markdown")

        runs ->
          atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("")

        runs ->
          atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/file with space.md")

        runs ->
          atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/áccéntéd.md")

        runs ->
          atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

  describe "when a preview has been created for the file", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        MarkdownPreviewView::renderMarkdown.reset()

    it "closes the existing preview when toggle is triggered a second time on the editor", ->
      atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      [editorPane, previewPane] = atom.workspace.getPanes()
      expect(editorPane.isActive()).toBe true
      expect(previewPane.getActiveItem()).toBeUndefined()

    it "closes the existing preview when toggle is triggered on it and it has focus", ->
      previewPane.activate()
      atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      [editorPane, previewPane] = atom.workspace.getPanes()
      expect(previewPane.getActiveItem()).toBeUndefined()

    describe "when the editor is modified", ->
      it "invokes ::onDidChangeMarkdown listeners", ->
        markdownEditor = atom.workspace.getActiveTextEditor()
        preview = previewPane.getActiveItem()
        preview.onDidChangeMarkdown(listener = jasmine.createSpy('didChangeMarkdownListener'))

        runs ->
          MarkdownPreviewView::renderMarkdown.reset()
          markdownEditor.setText("Hey!")

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(listener).toHaveBeenCalled()

      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          markdownEditor = atom.workspace.getActiveTextEditor()
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            MarkdownPreviewView::renderMarkdown.reset()
            markdownEditor.setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(previewPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          markdownEditor = atom.workspace.getActiveTextEditor()
          previewPane.splitRight(copyActiveItem: true)
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            MarkdownPreviewView::renderMarkdown.reset()
            editorPane.activate()
            markdownEditor.setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(editorPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).toBe preview

      describe "when the liveUpdate config is set to false", ->
        it "only re-renders the markdown when the editor is saved, not when the contents are modified", ->
          atom.config.set 'markdown-preview.liveUpdate', false

          didStopChangingHandler = jasmine.createSpy('didStopChangingHandler')
          atom.workspace.getActiveTextEditor().getBuffer().onDidStopChanging didStopChangingHandler
          atom.workspace.getActiveTextEditor().setText('ch ch changes')

          waitsFor ->
            didStopChangingHandler.callCount > 0

          runs ->
            expect(MarkdownPreviewView::renderMarkdown.callCount).toBe 0
            atom.workspace.getActiveTextEditor().save()
            expect(MarkdownPreviewView::renderMarkdown.callCount).toBe 1

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-javascript')

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

  describe "when the markdown preview view is requested by file URI", ->
    it "opens a preview editor and watches the file for changes", ->
      waitsForPromise "atom.workspace.open promise to be resolved", ->
        atom.workspace.open("markdown-preview://#{atom.project.resolve('subdir/file.markdown')}")

      runs ->
        expect(MarkdownPreviewView::renderMarkdown.callCount).toBeGreaterThan 0
        preview = atom.workspace.getActivePaneItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)

        MarkdownPreviewView::renderMarkdown.reset()
        preview.file.emitter.emit('did-change')

      waitsFor "renderMarkdown to be called", ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the markdown preview", ->
      atom.config.set('markdown-preview.grammars', [])

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "when the editor's path changes on #win32 and #darwin", ->
    it "updates the preview's title", ->
      titleChangedCallback = jasmine.createSpy('titleChangedCallback')

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview.getTitle()).toBe 'file.markdown Preview'

        titleChangedCallback.reset()
        preview.onDidChangeTitle(titleChangedCallback)
        fs.renameSync(atom.workspace.getActiveTextEditor().getPath(), path.join(path.dirname(atom.workspace.getActiveTextEditor().getPath()), 'file2.md'))

      waitsFor ->
        titleChangedCallback.callCount is 1

  describe "when the URI opened does not have a markdown-preview protocol", ->
    it "does not throw an error trying to decode the URI (regression)", ->
      waitsForPromise ->
        atom.workspace.open('%')

      runs ->
        expect(atom.workspace.getActiveTextEditor()).toBeTruthy()

  describe "when markdown-preview:copy-html is triggered", ->
    it "copies the HTML to the clipboard", ->
      waitsForPromise ->
        atom.workspace.open("subdir/simple.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
          <p><strong>bold</strong></p>
          <p>encoding \u2192 issue</p>
        """

        atom.workspace.getActiveTextEditor().setSelectedBufferRange [[0, 0], [1, 0]]
        atom.commands.dispatch workspaceElement, 'markdown-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
        """

  describe "sanitization", ->
    it "removes script tags and attributes that commonly contain inline scripts", ->
      waitsForPromise ->
        atom.workspace.open("subdir/evil.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe """
          <p>hello</p>
          <p></p>
          <p>
          <img>
          world</p>
        """

    it "remove the first <!doctype> tag at the beginning of the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/doctype-tag.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe """
          <p>content
          &lt;!doctype html&gt;</p>
        """

  describe "when the markdown contains an <html> tag", ->
    it "does not throw an exception", ->
      waitsForPromise ->
        atom.workspace.open("subdir/html-tag.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe "content"
