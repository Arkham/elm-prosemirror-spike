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

class ElmProseMirror extends HTMLElement {
  constructor() { super(); }

  connectedCallback() {
    this._initElement();
    this._initProseMirror();
  }

  attributeChangedCallback() { return; }

  static get observedAttributes() { return []; }

  _initElement() {
    this._element = document.createElement('div');
    this._element.id = 'prosemirror-root';
    this.appendChild(this._element);
  }

  _initProseMirror() {
    let self = this;
    this._editor = new EditorView(this._element, {
      state: EditorState.create({
        doc: defaultMarkdownParser.parse("# Hello darkness my old friend\n### I've come to talk with you again\nlorem ipsum, [google](www.google.com)\n\n- hoho\n- haha\n  - hehe"),
        plugins: exampleSetup({schema: mySchema})
      }),
      dispatchTransaction: function(tr) {
        this.updateState(this.state.apply(tr));
        const newState = this.state.doc.toJSON();
        console.log(JSON.stringify(newState, null, 2));
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
}

customElements.define('elm-prosemirror', ElmProseMirror);
