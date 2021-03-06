import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, Node} from "prosemirror-model"
import {schema} from "prosemirror-schema-basic"
import {addListNodes} from "prosemirror-schema-list"
import {exampleSetup} from "prosemirror-example-setup"
import {defaultMarkdownParser} from "prosemirror-markdown"

const marks = {
  highlight: {
    attrs: {
      id: {}
    },
    excludes: "",
    parseDOM: [{ tag: "[data-highlight-id]", getAttrs(dom) {
      return {id: dom.getAttribute("data-highlight-id")}
    }}],
    toDOM(node) { return ["span", { "data-highlight-id": node.attrs.id }, 0] },
  },

  link: {
    attrs: {
      href: {},
      title: {default: null}
    },
    inclusive: false,
    parseDOM: [{tag: "a[href]", getAttrs(dom) {
      return {href: dom.getAttribute("href"), title: dom.getAttribute("title")}
    }}],
    toDOM(node) { let {href, title} = node.attrs; return ["a", {href, title}, 0] }
  },

  em: {
    parseDOM: [{tag: "i"}, {tag: "em"}, {style: "font-style=italic"}],
    toDOM() { return ["em", 0] }
  },

  strong: {
    parseDOM: [{tag: "strong"},
               {tag: "b", getAttrs: node => node.style.fontWeight != "normal" && null},
               {style: "font-weight", getAttrs: value => /^(bold(er)?|[5-9]\d{2,})$/.test(value) && null}],
    toDOM() { return ["strong", 0] }
  }
}

// Mix the nodes from prosemirror-schema-list into the basic schema to
// create a schema with list support.
const mySchema = new Schema({
  nodes: addListNodes(schema.spec.nodes, "paragraph block*", "block"),
  marks: marks
})

const myPlugins = exampleSetup({schema: mySchema});

class ElmProseMirror extends HTMLElement {
  constructor() {
    super();
    this._appliedTransactions = new Set();
  }

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

  set transactions(transactions) {
    if (!this._editor || transactions.length < 1) return;

    let newTransactions = transactions.filter(transaction => !this._appliedTransactions.has(transaction.id));

    if (newTransactions.length < 1) return;

    newTransactions.forEach(transaction => this._appliedTransactions.add(transaction.id));

    let newTr = newTransactions.reduce((acc, transaction) => {
      return acc.addMark(transaction.from, transaction.to, mySchema.mark('highlight', { id: transaction.details.attrs.id }))
    }, this._editor.state.tr);

    this._editor.dispatch(newTr);
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

        const event = new CustomEvent('change', {
          detail: {
            state: newState,
            selection: {
              from: tr.selection.from,
              to: tr.selection.to
            }
          }
        });

        self.dispatchEvent(event);
      }
    });
  }
}

customElements.define('elm-prosemirror', ElmProseMirror);
