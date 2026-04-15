# Python sample for tree-sitter demo
from dataclasses import dataclass
from typing import Optional, List

@dataclass
class Node:
    value: int
    left: Optional['Node'] = None
    right: Optional['Node'] = None

def insert(root: Optional[Node], value: int) -> Node:
    if root is None:
        return Node(value)
    if value < root.value:
        root.left = insert(root.left, value)
    elif value > root.value:
        root.right = insert(root.right, value)
    return root

def inorder(root: Optional[Node]) -> List[int]:
    if root is None:
        return []
    return inorder(root.left) + [root.value] + inorder(root.right)

def main():
    values = [5, 3, 7, 1, 4, 6, 8]
    root = None
    for v in values:
        root = insert(root, v)
    print("Sorted:", inorder(root))

if __name__ == "__main__":
    main()
