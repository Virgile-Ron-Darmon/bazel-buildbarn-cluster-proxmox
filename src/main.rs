#![allow(long_running_const_eval)]


const fn fib(n: u64) -> u64 {
    if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
}

const RESULT: u64 = fib(25);

fn main() {
    println!("{}", RESULT);
}