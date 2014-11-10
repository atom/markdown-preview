path = require 'path'
{WorkspaceView} = require 'atom'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
MarkdownPreviewView = require '../lib/markdown-preview-view'

describe "Markdown preview package", ->
  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPath(tempPath)
    jasmine.unspy(window, 'setTimeout')

    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model

    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown').andCallThrough()

    waitsForPromise ->
      atom.packages.activatePackage("markdown-preview")

    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')

  describe "when a preview has not been created for the file", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "splits the current pane to the right with a markdown preview for the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        expect(atom.workspaceView.getPaneViews()).toHaveLength 2
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()

        expect(editorPane.items).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(MarkdownPreviewView)
        expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
        expect(editorPane).toHaveFocus()

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("new.markdown")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPaneViews()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPaneViews()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a markdown preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPaneViews()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPaneViews()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/file with space.md")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPaneViews()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPaneViews()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/áccéntéd.md")

        runs ->
          atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

        waitsFor ->
          MarkdownPreviewView::renderMarkdown.callCount > 0

        runs ->
          expect(atom.workspaceView.getPaneViews()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPaneViews()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

  describe "when a preview has been created for the file", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()
        preview = previewPane.getActiveItem()
        MarkdownPreviewView::renderMarkdown.reset()

    it "closes the existing preview when toggle is triggered a second time on the editor", ->
      atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      [editorPane, previewPane] = atom.workspaceView.getPaneViews()
      expect(editorPane).toHaveFocus()
      expect(previewPane?.activeItem).toBeUndefined()

    it "closes the existing preview when toggle is triggered on it and it has focus", ->
      previewPane.focus()
      atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      [editorPane, previewPane] = atom.workspaceView.getPaneViews()
      expect(previewPane?.activeItem).toBeUndefined()

    describe "when the editor is modified", ->
      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          markdownEditor = atom.workspace.getActiveEditor()
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            MarkdownPreviewView::renderMarkdown.reset()
            markdownEditor.setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(previewPane).toHaveFocus()
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          markdownEditor = atom.workspace.getActiveEditor()
          atom.commands.dispatch(previewPane[0], 'pane:split-right')
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            MarkdownPreviewView::renderMarkdown.reset()
            editorPane.focus()
            markdownEditor.setText("Hey!")

          waitsFor ->
            MarkdownPreviewView::renderMarkdown.callCount > 0

          runs ->
            expect(editorPane).toHaveFocus()
            expect(previewPane.getActiveItem()).toBe preview

      describe "when the liveUpdate config is set to false", ->
        it "only re-renders the markdown when the editor is saved, not when the contents are modified", ->
          atom.config.set 'markdown-preview.liveUpdate', false

          contentsModifiedHandler = jasmine.createSpy('contents-modified')
          atom.workspace.getActiveEditor().getBuffer().on 'contents-modified', contentsModifiedHandler
          atom.workspace.getActiveEditor().setText('ch ch changes')

          waitsFor ->
            contentsModifiedHandler.callCount > 0

          runs ->
            expect(MarkdownPreviewView::renderMarkdown.callCount).toBe 0
            atom.workspace.getActiveEditor().save()
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
        preview.file.emit('contents-changed')

      waitsFor "renderMarkdown to be called", ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the markdown preview", ->
      atom.config.set('markdown-preview.grammars', [])

      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "when the editor's path changes on #win32 and #darwin", ->
    it "updates the preview's title", ->
      titleChangedCallback = jasmine.createSpy('titleChangedCallback')

      waitsForPromise ->
        atom.workspace.open("subdir/file.markdown")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()
        preview = previewPane.getActiveItem()
        expect(preview.getTitle()).toBe 'file.markdown Preview'

        titleChangedCallback.reset()
        preview.one('title-changed', titleChangedCallback)
        fs.renameSync(atom.workspace.getActiveEditor().getPath(), path.join(path.dirname(atom.workspace.getActiveEditor().getPath()), 'file2.md'))

      waitsFor ->
        titleChangedCallback.callCount is 1

  describe "when the URI opened does not have a markdown-preview protocol", ->
    it "does not throw an error trying to decode the URI (regression)", ->
      waitsForPromise ->
        atom.workspace.open('%')

      runs ->
        expect(atom.workspace.getActiveEditor()).toBeTruthy()

  describe "when markdown-preview:copy-html is triggered", ->
    it "copies the HTML to the clipboard", ->
      waitsForPromise ->
        atom.workspace.open("subdir/simple.md")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
          <p><strong>bold</strong></p>
          <p>encoding \u2192 issue</p>
        """

        atom.workspace.getActiveEditor().setSelectedBufferRange [[0, 0], [1, 0]]
        atom.workspaceView.getActiveView().trigger 'markdown-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
        """

  describe "sanitization", ->
    it "removes script tags and attributes that commonly contain inline scripts", ->
      waitsForPromise ->
        atom.workspace.open("subdir/evil.md")

      runs ->
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()
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
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()
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
        atom.workspaceView.getActiveView().trigger 'markdown-preview:toggle'

      waitsFor ->
        MarkdownPreviewView::renderMarkdown.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPaneViews()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe "content"
