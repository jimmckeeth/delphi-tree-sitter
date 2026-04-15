/* C sample for tree-sitter demo */
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int value;
    struct Node *left;
    struct Node *right;
} Node;

Node *node_new(int value) {
    Node *n = (Node *)malloc(sizeof(Node));
    n->value = value;
    n->left = NULL;
    n->right = NULL;
    return n;
}

Node *insert(Node *root, int value) {
    if (root == NULL)
        return node_new(value);
    if (value < root->value)
        root->left = insert(root->left, value);
    else if (value > root->value)
        root->right = insert(root->right, value);
    return root;
}

void inorder(Node *root) {
    if (root == NULL) return;
    inorder(root->left);
    printf("%d ", root->value);
    inorder(root->right);
}

int main(void) {
    int values[] = {5, 3, 7, 1, 4, 6, 8};
    int n = sizeof(values) / sizeof(values[0]);
    Node *root = NULL;
    for (int i = 0; i < n; i++)
        root = insert(root, values[i]);
    inorder(root);
    printf("\n");
    return 0;
}
