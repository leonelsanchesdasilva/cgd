fn eh_primo(n: u32) -> bool {
    if n < 2 {
        return false;
    }
    if n == 2 {
        return true;
    }
    if n % 2 == 0 {
        return false;
    }

    let limite = (n as f64).sqrt() as u32;
    for i in (3..=limite).step_by(2) {
        if n % i == 0 {
            return false;
        }
    }
    true
}

fn contar_primos(limite: u32) -> u32 {
    let mut contador = 0;
    for numero in 2..=limite {
        if eh_primo(numero) {
            contador += 1;
        }
    }
    contador
}

fn main() {
    let limite = 1000000;

    let resultado = contar_primos(limite);
    println!("RESULT:{}", resultado);
}
