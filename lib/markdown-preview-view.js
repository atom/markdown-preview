const path = require('path')

const { Emitter, Disposable, CompositeDisposable, File } = require('atom')
const _ = require('underscore-plus')
const fs = require('fs-plus')

const renderer = require('./renderer')

module.exports = class MarkdownPreviewView {
  static deserialize (params) {
    return new MarkdownPreviewView(params)
  }

  constructor ({ editorId, filePath }) {
    this.editorId = editorId
    this.filePath = filePath
    this.element = document.createElement('div')
    this.element.classList.add('markdown-preview')
    this.element.tabIndex = -1
    this.emitter = new Emitter()
    this.loaded = false
    this.disposables = new CompositeDisposable()
    this.registerScrollCommands()
    if (this.editorId != null) {
      this.resolveEditor(this.editorId)
    } else if (atom.packages.hasActivatedInitialPackages()) {
      this.subscribeToFilePath(this.filePath)
    } else {
      this.disposables.add(
        atom.packages.onDidActivateInitialPackages(() => {
          return this.subscribeToFilePath(this.filePath)
        })
      )
    }
  }

  serialize () {
    return {
      deserializer: 'MarkdownPreviewView',
      filePath: this.getPath() != null ? this.getPath() : this.filePath,
      editorId: this.editorId
    }
  }

  copy () {
    return new MarkdownPreviewView({
      editorId: this.editorId,
      filePath: this.getPath() != null ? this.getPath() : this.filePath
    })
  }

  destroy () {
    this.disposables.dispose()
    return this.element.remove()
  }

  registerScrollCommands () {
    this.disposables.add(
      atom.commands.add(this.element, {
        'core:move-up': () => {
          this.element.scrollTop -= document.body.offsetHeight / 20
        },
        'core:move-down': () => {
          this.element.scrollTop += document.body.offsetHeight / 20
        },
        'core:page-up': () => {
          this.element.scrollTop -= this.element.offsetHeight
        },
        'core:page-down': () => {
          this.element.scrollTop += this.element.offsetHeight
        },
        'core:move-to-top': () => {
          this.element.scrollTop = 0
        },
        'core:move-to-bottom': () => {
          this.element.scrollTop = this.element.scrollHeight
        }
      })
    )
  }

  onDidChangeTitle (callback) {
    return this.emitter.on('did-change-title', callback)
  }

  onDidChangeModified (callback) {
    // No op to suppress deprecation warning
    return new Disposable()
  }

  onDidChangeMarkdown (callback) {
    return this.emitter.on('did-change-markdown', callback)
  }

  subscribeToFilePath (filePath) {
    this.file = new File(filePath)
    this.emitter.emit('did-change-title')
    this.disposables.add(
      this.file.onDidRename(() => this.emitter.emit('did-change-title'))
    )
    this.handleEvents()
    return this.renderMarkdown()
  }

  resolveEditor (editorId) {
    const resolve = () => {
      this.editor = this.editorForId(editorId)

      if (this.editor != null) {
        this.emitter.emit('did-change-title')
        this.disposables.add(
          this.editor.onDidDestroy(() =>
            this.subscribeToFilePath(this.getPath())
          )
        )
        this.handleEvents()
        return this.renderMarkdown()
      } else {
        return this.subscribeToFilePath(this.filePath)
      }
    }

    if (atom.packages.hasActivatedInitialPackages()) {
      return resolve()
    } else {
      return this.disposables.add(
        atom.packages.onDidActivateInitialPackages(resolve)
      )
    }
  }

  editorForId (editorId) {
    for (const editor of atom.workspace.getTextEditors()) {
      if (
        (editor.id != null ? editor.id.toString() : undefined) ===
        editorId.toString()
      ) {
        return editor
      }
    }
    return null
  }

  handleEvents () {
    const lazyRenderMarkdown = _.debounce(() => this.renderMarkdown(), 250)
    this.disposables.add(
      atom.grammars.onDidAddGrammar(() => lazyRenderMarkdown())
    )
    if (typeof atom.grammars.onDidRemoveGrammar === 'function') {
      this.disposables.add(
        atom.grammars.onDidRemoveGrammar(() => lazyRenderMarkdown())
      )
    } else {
      // TODO: Remove onDidUpdateGrammar hook once onDidRemoveGrammar is released
      this.disposables.add(
        atom.grammars.onDidUpdateGrammar(() => lazyRenderMarkdown())
      )
    }

    atom.commands.add(this.element, {
      'core:copy': event => {
        event.stopPropagation()
        return this.copyToClipboard()
      },
      'markdown-preview:select-all': () => {
        return this.selectAll()
      },
      'markdown-preview:zoom-in': () => {
        const zoomLevel = parseFloat(getComputedStyle(this.element).zoom)
        return (this.element.style.zoom = zoomLevel + 0.1)
      },
      'markdown-preview:zoom-out': () => {
        const zoomLevel = parseFloat(getComputedStyle(this.element).zoom)
        return (this.element.style.zoom = zoomLevel - 0.1)
      },
      'markdown-preview:reset-zoom': () => {
        return (this.element.style.zoom = 1)
      },
      'markdown-preview:toggle-break-on-single-newline' () {
        const keyPath = 'markdown-preview.breakOnSingleNewline'
        return atom.config.set(keyPath, !atom.config.get(keyPath))
      },
      'markdown-preview:toggle-github-style' () {
        const keyPath = 'markdown-preview.useGitHubStyle'
        return atom.config.set(keyPath, !atom.config.get(keyPath))
      }
    })

    const changeHandler = () => {
      this.renderMarkdown()

      const pane = atom.workspace.paneForItem(this)
      if (pane != null && pane !== atom.workspace.getActivePane()) {
        return pane.activateItem(this)
      }
    }

    if (this.file) {
      this.disposables.add(this.file.onDidChange(changeHandler))
    } else if (this.editor) {
      this.disposables.add(
        this.editor.getBuffer().onDidStopChanging(function () {
          if (atom.config.get('markdown-preview.liveUpdate')) {
            return changeHandler()
          }
        })
      )
      this.disposables.add(
        this.editor.onDidChangePath(() => this.emitter.emit('did-change-title'))
      )
      this.disposables.add(
        this.editor.getBuffer().onDidSave(function () {
          if (!atom.config.get('markdown-preview.liveUpdate')) {
            return changeHandler()
          }
        })
      )
      this.disposables.add(
        this.editor.getBuffer().onDidReload(function () {
          if (!atom.config.get('markdown-preview.liveUpdate')) {
            return changeHandler()
          }
        })
      )
    }

    this.disposables.add(
      atom.config.onDidChange(
        'markdown-preview.breakOnSingleNewline',
        changeHandler
      )
    )

    this.disposables.add(
      atom.config.observe('markdown-preview.useGitHubStyle', useGitHubStyle => {
        if (useGitHubStyle) {
          return this.element.setAttribute('data-use-github-style', '')
        } else {
          return this.element.removeAttribute('data-use-github-style')
        }
      })
    )

    return (document.onselectionchange = () => {
      const selection = window.getSelection()
      const selectedNode = selection.baseNode
      if (
        selectedNode === null ||
        this.element === selectedNode ||
        this.element.contains(selectedNode)
      ) {
        if (selection.isCollapsed) {
          return this.element.classList.remove('has-selection')
        } else {
          return this.element.classList.add('has-selection')
        }
      }
    })
  }

  renderMarkdown () {
    if (!this.loaded) {
      this.showLoading()
    }
    return this.getMarkdownSource()
      .then(source => {
        if (source != null) {
          return this.renderMarkdownText(source)
        }
      })
      .catch(reason => this.showError({ message: reason }))
  }

  getMarkdownSource () {
    if (this.file != null ? this.file.getPath() : undefined) {
      return this.file
        .read()
        .then(source => {
          if (source === null) {
            return Promise.reject(
              `${this.file.getBaseName()} could not be found`
            )
          } else {
            return Promise.resolve(source)
          }
        })
        .catch(reason => Promise.reject(reason))
    } else if (this.editor != null) {
      return Promise.resolve(this.editor.getText())
    } else {
      return Promise.reject()
    }
  }

  getHTML (callback) {
    return this.getMarkdownSource().then(source => {
      if (source == null) {
        return
      }

      return renderer.toHTML(
        source,
        this.getPath(),
        this.getGrammar(),
        callback
      )
    })
  }

  renderMarkdownText (text) {
    const { scrollTop } = this.element
    return renderer.toDOMFragment(
      text,
      this.getPath(),
      this.getGrammar(),
      (error, domFragment) => {
        if (error) {
          return this.showError(error)
        } else {
          this.loading = false
          this.loaded = true
          this.element.textContent = ''
          this.element.appendChild(domFragment)
          this.emitter.emit('did-change-markdown')
          return (this.element.scrollTop = scrollTop)
        }
      }
    )
  }

  getTitle () {
    if (this.file != null && this.getPath() != null) {
      return `${path.basename(this.getPath())} Preview`
    } else if (this.editor != null) {
      return `${this.editor.getTitle()} Preview`
    } else {
      return 'Markdown Preview'
    }
  }

  getIconName () {
    return 'markdown'
  }

  getURI () {
    if (this.file != null) {
      return `markdown-preview://${this.getPath()}`
    } else {
      return `markdown-preview://editor/${this.editorId}`
    }
  }

  getPath () {
    if (this.file != null) {
      return this.file.getPath()
    } else if (this.editor != null) {
      return this.editor.getPath()
    }
  }

  getGrammar () {
    return this.editor != null ? this.editor.getGrammar() : undefined
  }

  getDocumentStyleSheets () {
    // This function exists so we can stub it
    return document.styleSheets
  }

  getTextEditorStyles () {
    const textEditorStyles = document.createElement('atom-styles')
    textEditorStyles.initialize(atom.styles)
    textEditorStyles.setAttribute('context', 'atom-text-editor')
    document.body.appendChild(textEditorStyles)

    // Extract style elements content
    return Array.prototype.slice
      .apply(textEditorStyles.childNodes)
      .map(styleElement => styleElement.innerText)
  }

  getMarkdownPreviewCSS () {
    const markdownPreviewRules = []
    const ruleRegExp = /\.markdown-preview/
    const cssUrlRegExp = /url\(atom:\/\/markdown-preview\/assets\/(.*)\)/

    for (const stylesheet of this.getDocumentStyleSheets()) {
      if (stylesheet.rules != null) {
        for (const rule of stylesheet.rules) {
          // We only need `.markdown-review` css
          if (
            (rule.selectorText != null
              ? rule.selectorText.match(ruleRegExp)
              : undefined) != null
          ) {
            markdownPreviewRules.push(rule.cssText)
          }
        }
      }
    }

    return markdownPreviewRules
      .concat(this.getTextEditorStyles())
      .join('\n')
      .replace(/atom-text-editor/g, 'pre.editor-colors')
      .replace(/:host/g, '.host') // Remove shadow-dom :host selector causing problem on FF
      .replace(cssUrlRegExp, function (match, assetsName, offset, string) {
        // base64 encode assets
        const assetPath = path.join(__dirname, '../assets', assetsName)
        const originalData = fs.readFileSync(assetPath, 'binary')
        const base64Data = new Buffer(originalData, 'binary').toString('base64')
        return `url('data:image/jpeg;base64,${base64Data}')`
      })
  }

  showError (result) {
    let failureMessage
    this.element.textContent = ''
    const h2 = document.createElement('h2')
    h2.textContent = 'Previewing Markdown Failed'
    this.element.appendChild(h2)
    if ((failureMessage = result != null ? result.message : undefined)) {
      const h3 = document.createElement('h3')
      h3.textContent = failureMessage
      return this.element.appendChild(h3)
    }
  }

  showLoading () {
    this.loading = true
    this.element.textContent = ''
    const div = document.createElement('div')
    div.classList.add('markdown-spinner')
    div.textContent = 'Loading Markdown\u2026'
    return this.element.appendChild(div)
  }

  selectAll () {
    if (this.loading) {
      return
    }

    const selection = window.getSelection()
    selection.removeAllRanges()
    const range = document.createRange()
    range.selectNodeContents(this.element)
    return selection.addRange(range)
  }

  copyToClipboard () {
    if (this.loading) {
      return
    }

    const selection = window.getSelection()
    const selectedText = selection.toString()
    const selectedNode = selection.baseNode

    // Use default copy event handler if there is selected text inside this view
    if (
      selectedText &&
      selectedNode != null &&
      (this.element === selectedNode || this.element.contains(selectedNode))
    ) {
      return atom.clipboard.write(selectedText)
    } else {
      return this.getHTML(function (error, html) {
        if (error != null) {
          return atom.notifications.addError(
            'Copying Markdown as HTML failed',
            { dismissable: true, detail: error.message }
          )
        } else {
          return atom.clipboard.write(html)
        }
      })
    }
  }

  getSaveDialogOptions () {
    let defaultPath = this.getPath()
    if (defaultPath) {
      defaultPath += '.html'
    } else {
      let projectPath
      defaultPath = 'untitled.md.html'
      if ((projectPath = atom.project.getPaths()[0])) {
        defaultPath = path.join(projectPath, defaultPath)
      }
    }

    return { defaultPath }
  }

  saveAs (htmlFilePath) {
    if (this.loading) {
      atom.notifications.addWarning(
        'Please wait until the Markdown Preview has finished loading before saving'
      )
      return
    }

    const filePath = this.getPath()
    let title = 'Markdown to HTML'
    if (filePath) {
      title = path.parse(filePath).name
    }

    return new Promise((resolve, reject) => {
      return this.getHTML((error, htmlBody) => {
        if (error != null) {
          throw error
        } else {
          const html =
            `\
<!DOCTYPE html>
<html>
  <head>
      <meta charset="utf-8" />
      <title>${title}</title>
      <style>${this.getMarkdownPreviewCSS()}</style>
  </head>
  <body class='markdown-preview' data-use-github-style>${htmlBody}</body>
</html>` + '\n' // Ensure trailing newline

          fs.writeFileSync(htmlFilePath, html)
          return atom.workspace.open(htmlFilePath).then(resolve)
        }
      })
    })
  }
}
