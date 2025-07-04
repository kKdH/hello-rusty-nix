use std::env;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let environment = env::vars()
        .filter(|env| env.0.starts_with("RUSTY_NIX_"))
        .collect::<Vec<_>>();

    for (key, value) in environment {
        println!("{key}={value}");
    }

    println!("Hello, Rusty Nix!");

    Ok(())
}
