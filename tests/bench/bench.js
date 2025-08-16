function ehPrimo(n) {
    if (n < 2) return false;
    if (n === 2) return true;
    if (n % 2 === 0) return false;
    
    const limite = Math.floor(Math.sqrt(n));
    for (let i = 3; i <= limite; i += 2) {
        if (n % i === 0) return false;
    }
    return true;
}

function contarPrimos(limite) {
    let contador = 0;
    for (let numero = 2; numero <= limite; numero++) {
        if (ehPrimo(numero)) contador++;
    }
    return contador;
}

function main() {
    const limite = 1000000;
    
    // Warm-up para V8
    contarPrimos(1000);
    
    const resultado = contarPrimos(limite);
    console.log(`RESULT:${resultado}`);
}

main();
