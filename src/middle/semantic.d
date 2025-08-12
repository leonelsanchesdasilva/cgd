module middle.semantic;

import middle.semantic_symbol_info;
import middle.function_builder;
import middle.std_lib_module_builder;
import middle.type_checker;
import frontend.parser.ast;

class Semantic
{
public:
    SymbolInfo[string] scopeStack = [];
    StdLibFunction[string] availableFunctions = [];
    bool[string] importedModules = [];
    StdLibModule[string] stdLibs = [];
    bool[string] identifiersUsed = [];
private:
    Stmt[] externalNodes = [];
    TypeChecker typeChecker;

    void pushScope()
    {
        this.scopeStack ~= [];
    }

    void popScope()
    {
        if (this.scopeStack.length <= 1)
        {
            // Cannot pop the global scope.
        }
        this.scopeStack.length -= 1; // arr.pop()
    }

    SymbolInfo[string] currentScope()
    {
        return this.scopeStack[cast(int) this.scopeStack.length - 1];
    }
}
