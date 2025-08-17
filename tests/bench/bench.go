package main

import (
    "fmt"
    "math"
)

func ehPrimo(n int) bool {
    if n < 2 { return false }
    if n == 2 { return true }
    if n % 2 == 0 { return false }
    
    limite := int(math.Sqrt(float64(n)))
    for i := 3; i <= limite; i += 2 {
        if n % i == 0 { return false }
    }
    return true
}

func contarPrimos(limite int) int {
    contador := 0
    for numero := 2; numero <= limite; numero++ {
        if ehPrimo(numero) {
            contador++
        }
    }
    return contador
}

func main() {
    limite := 1000000
    
    resultado := contarPrimos(limite)
    fmt.Printf("RESULT:%d\n", resultado)
}
