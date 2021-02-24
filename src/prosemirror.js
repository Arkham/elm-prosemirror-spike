import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, Node} from "prosemirror-model"
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

class ElmProseMirror extends HTMLElement {
  constructor() { super(); }

  connectedCallback() {
    this._initElement();
    this._initProseMirror();
  }

  attributeChangedCallback() { return; }

  static get observedAttributes() { return []; }

  set content(content) {
    if (!this._content) {
      this._content = content;
    }
  }

  _initElement() {
    this._element = document.createElement('div');
    this._element.id = 'prosemirror-root';
    this.appendChild(this._element);
  }

  _initProseMirror() {
    if (!this._content) { return; }

    let self = this;

    this._editor = new EditorView(this._element, {
      state: EditorState.create({
        doc: Node.fromJSON(mySchema, this._content),
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
}

customElements.define('elm-prosemirror', ElmProseMirror);
