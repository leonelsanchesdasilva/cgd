import math

def eh_primo(n):
    if n < 2: return False
    if n == 2: return True
    if n % 2 == 0: return False
    
    # Otimização: usar int ao invés de float
    limite = int(math.sqrt(n)) + 1
    for i in range(3, limite, 2):
        if n % i == 0: return False
    return True

def contar_primos(limite):
    contador = 0
    for numero in range(2, limite + 1):
        if eh_primo(numero):
            contador += 1
    return contador

def main():
    limite = 1000000
    
    # Warm-up para JIT
    contar_primos(1000)
    
    resultado = contar_primos(limite)
    print(f"RESULT:{resultado}")

if __name__ == "__main__":
    main()
