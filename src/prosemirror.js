import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "prosemirror-schema-basic"
import {addListNodes} from "prosemirror-schema-list"
import {exampleSetup} from "prosemirror-example-setup"
import {defaultMarkdownParser} from "prosemirror-markdown"

// Mix the nodes from prosemirror-schema-list into the basic schema to
// create a schema with list support.
const mySchema = new Schema({
  nodes: addListNodes(schema.spec.nodes, "paragraph block*", "block"),
  marks: schema.spec.marks
})

const myPlugins = exampleSetup({schema: mySchema});

const stateFromJSON = EditorState.fromJSON;

class ElmProseMirror extends HTMLElement {
  constructor() { super(); }

  connectedCallback() {
    this._initElement();
    this._initProseMirror();
    this._updateProseMirror();
  }

  attributeChangedCallback() { return; }

  static get observedAttributes() { return []; }

  set content(content) {
    this._content = content;
    this._updateProseMirror();
  }

  _initElement() {
    this._element = document.createElement('div');
    this._element.id = 'prosemirror-root';
    this.appendChild(this._element);
  }

  _initProseMirror() {
    let self = this;
    this._editor = new EditorView(this._element, {
      state: EditorState.create({
        // doc: defaultMarkdownParser.parse("# Hello darkness my old friend\n### I've come to talk with you again\nlorem ipsum, [google](www.google.com)\n\n- hoho\n- haha\n  - hehe"),
        doc: defaultMarkdownParser.parse(""),
        plugins: myPlugins
      }),
      dispatchTransaction: function(tr) {
        this.updateState(this.state.apply(tr));
        const newState = this.state.doc.toJSON();
        console.log(JSON.stringify(newState));
        console.log(tr.selection.from);
        console.log(tr.selection.to);

        const event = new CustomEvent('change', {
          detail: {
            state: newState
          }
        });

        self.dispatchEvent(event);
      }
    });
  }

  _updateProseMirror() {
    if (!this._editor || !this._content) return;

    // ugly hack
    if (JSON.stringify(this._editor.state.doc.toJSON()) == JSON.stringify(this._content)) return;

    const newState = EditorState.fromJSON({schema: mySchema, plugins: myPlugins}, {
      doc: this._content,
      selection: this._editor.state.selection.toJSON()
    });

    this._editor.updateState(newState);
  }
}

customElements.define('elm-prosemirror', ElmProseMirror);
