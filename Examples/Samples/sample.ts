interface Greeter {
    greet(): void;
}

class HelloWorld implements Greeter {
    greet() {
        console.log("Hello, Tree-sitter from TypeScript!");
    }
}

const greeter = new HelloWorld();
greeter.greet();
