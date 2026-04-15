// JavaScript sample for tree-sitter demo
class TreeNode {
  constructor(value) {
    this.value = value;
    this.children = [];
  }

  addChild(node) {
    this.children.push(node);
    return this;
  }

  walk(visitor) {
    visitor(this);
    for (const child of this.children) {
      child.walk(visitor);
    }
  }
}

function buildTree(depth, value = 0) {
  const node = new TreeNode(value);
  if (depth > 0) {
    node.addChild(buildTree(depth - 1, value * 2 + 1));
    node.addChild(buildTree(depth - 1, value * 2 + 2));
  }
  return node;
}

const root = buildTree(3);
const values = [];
root.walk(n => values.push(n.value));
console.log('Tree values:', values);
